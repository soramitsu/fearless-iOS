import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFUtils

final class IrohaHistoryOperationFactory {
    static let toriiCursorKey = "cursor"

    /// Torii scans about 500 blocks per history request, whatever the limit, so one page of
    /// transfers may take several requests. A page stops after this many.
    static let maximumToriiRequestsPerPage = 10

    private let client: IrohaToriiClientProtocol

    init(client: IrohaToriiClientProtocol = IrohaToriiClient()) {
        self.client = client
    }

    static func supports(chain: ChainModel) -> Bool {
        network(for: chain) != nil
    }

    private static func network(for chain: ChainModel) -> UniversalWalletRegistry.IrohaNetwork? {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.taira.chainId, UniversalWalletRegistry.taira.id:
            return UniversalWalletRegistry.taira
        case UniversalWalletRegistry.nexus.chainId, UniversalWalletRegistry.nexus.id:
            return UniversalWalletRegistry.nexus
        default:
            return nil
        }
    }

    private func shouldFetch(filters: [WalletTransactionHistoryFilter]) -> Bool {
        filters.isEmpty || filters.contains { $0.type == .transfer && $0.selected }
    }

    private func historyBaseURL(
        for chain: ChainModel,
        network: UniversalWalletRegistry.IrohaNetwork
    ) -> String? {
        if network == UniversalWalletRegistry.taira {
            return network.toriiBaseURL?.absoluteString
        }

        return chain.externalApi?.history?.url.absoluteString ?? network.toriiBaseURL?.absoluteString
    }

    private func normalizedAddress(
        _ address: String,
        network: UniversalWalletRegistry.IrohaNetwork
    ) -> String? {
        try? IrohaAddressCodec.parse(address, expectedDiscriminant: network.chainDiscriminant).i105
    }

    private func createHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        network: UniversalWalletRegistry.IrohaNetwork,
        address: String,
        pagination: Pagination
    ) -> BaseOperation<AssetTransactionPageData?> {
        let baseURL = historyBaseURL(for: chain, network: network)

        // Taira and Nexus both read history from Torii REST, never the MCP endpoint. Errors
        // reach the caller, so the history screen keeps the rows it has and offers a retry. An
        // empty page would replace cached history and look like an account without transfers.
        return AwaitOperation { [client] in
            try await self.fetchToriiHistoryPage(
                client: client,
                asset: asset,
                network: network,
                address: address,
                cursor: pagination.context?[Self.toriiCursorKey],
                limit: min(pagination.count, IrohaToriiRoutes.maxLimit),
                baseURL: baseURL
            )
        }
    }

    private func fetchToriiHistoryPage(
        client: IrohaToriiClientProtocol,
        asset: AssetModel,
        network: UniversalWalletRegistry.IrohaNetwork,
        address: String,
        cursor: String?,
        limit: Int,
        baseURL: String?
    ) async throws -> AssetTransactionPageData {
        let filter = try IrohaToriiRoutes.transferHistoryFilter(assetDefinitionIDs: [asset.id])
        var nextCursor = cursor
        var seenCursors = Set([cursor].compactMap { $0 })
        var pageFingerprints = Set<String>()
        var transactions: [AssetTransactionData] = []
        var requestCount = 0

        // A filtered page can be empty while older transfers remain. Follow those continuations
        // up to the bound, then return what was found with the cursor: an account without recent
        // transfers shows no rows instead of an error, and the next page resumes from the cursor.
        repeat {
            let response = try await client.accountHistory(
                accountID: address,
                baseURL: baseURL,
                limit: limit,
                cursor: nextCursor,
                filter: filter,
                network: network
            )
            requestCount += 1

            let fingerprint = response.items.map(\.id).joined(separator: "\u{1F}")
            guard response.items.isEmpty || pageFingerprints.insert(fingerprint).inserted else {
                throw ConvenienceError(error: "Iroha account-history pagination repeated a page")
            }
            transactions += response.items.compactMap {
                $0.transactionData(accountAddress: address, asset: asset)
            }

            nextCursor = response.nextCursor.flatMap { $0.isEmpty ? nil : $0 }
            if let nextCursor, !seenCursors.insert(nextCursor).inserted {
                throw ConvenienceError(error: "Iroha account-history pagination made no progress")
            }
        } while transactions.isEmpty && nextCursor != nil && requestCount < Self.maximumToriiRequestsPerPage

        return AssetTransactionPageData(
            transactions: transactions,
            context: nextCursor.map { [Self.toriiCursorKey: $0] }
        )
    }

    private func emptyPage() -> CompoundOperationWrapper<AssetTransactionPageData?> {
        CompoundOperationWrapper.createWithResult(AssetTransactionPageData(transactions: []))
    }
}

extension IrohaHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard
            let network = Self.network(for: chain),
            pagination.count >= 1,
            shouldFetch(filters: filters),
            let normalizedAddress = normalizedAddress(address, network: network)
        else {
            return emptyPage()
        }

        let historyOperation = createHistoryOperation(
            asset: asset,
            chain: chain,
            network: network,
            address: normalizedAddress,
            pagination: pagination
        )

        return CompoundOperationWrapper(targetOperation: historyOperation)
    }
}

private extension IrohaAccountHistoryItem {
    func transactionData(
        accountAddress: String,
        asset: AssetModel
    ) -> AssetTransactionData? {
        guard type.caseInsensitiveEquals("TRANSFER"),
              accountID.caseInsensitiveEquals(accountAddress),
              assetDefinitionID == asset.id,
              assetID?.irohaAssetMatches(asset.id) == true,
              let amount,
              let decimalAmount = canonicalIrohaDecimal(
                  amount,
                  maximumScale: Int(asset.precision)
              ),
              let timestampMs,
              timestampMs <= UInt64(Int64.max),
              let transactionType = transactionType,
              let transactionStatus = transactionStatus,
              let peerAddress = peerAddress(accountAddress: accountAddress),
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return AssetTransactionData(
            transactionId: id,
            status: transactionStatus,
            assetId: asset.id,
            peerId: peerAddress,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress.isEmpty ? nil : peerAddress,
            details: "",
            amount: AmountDecimal(value: decimalAmount),
            fees: [],
            timestamp: Int64(timestampMs / 1000),
            type: transactionType.rawValue,
            reason: "",
            context: nil
        )
    }

    private var transactionType: TransactionType? {
        if direction.caseInsensitiveEquals("incoming") {
            return .incoming
        }
        if direction.caseInsensitiveEquals("outgoing") {
            return .outgoing
        }
        if direction.caseInsensitiveEquals("self") {
            return .outgoing
        }

        return nil
    }

    private func peerAddress(accountAddress: String) -> String? {
        if direction.caseInsensitiveEquals("self") {
            return accountAddress
        }

        let peerAddress = counterpartyAccountID?.trimmingCharacters(in: .whitespacesAndNewlines)
        return peerAddress?.isEmpty == false ? peerAddress : nil
    }

    private var transactionStatus: AssetTransactionStatus? {
        if status.caseInsensitiveEquals("SUCCESS"), resultOk != false {
            return .commited
        }
        if status.caseInsensitiveEquals("FAILED") || status.caseInsensitiveEquals("REJECTED"),
           resultOk != true {
            return .rejected
        }

        return nil
    }
}

private func canonicalIrohaDecimal(
    _ rawValue: String,
    maximumScale: Int
) -> Decimal? {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, maximumScale >= 0 else {
        return nil
    }

    let components = value.split(separator: ".", omittingEmptySubsequences: false)
    guard components.count <= 2,
          let integer = components.first,
          !integer.isEmpty,
          integer.utf8.allSatisfy({ (48 ... 57).contains($0) }),
          components.count == 1 ||
          (!components[1].isEmpty &&
              components[1].utf8.allSatisfy { (48 ... 57).contains($0) } &&
              components[1].count <= maximumScale),
          maximumScale <= Int(Int16.max) else {
        return nil
    }

    let fraction = components.count == 2 ? String(components[1]) : ""
    let exactPlanksString = String(integer) + fraction + String(
        repeating: "0",
        count: maximumScale - fraction.count
    )
    guard let exactPlanks = BigUInt(exactPlanksString), exactPlanks > .zero,
          let decimal = Decimal(
              string: value,
              locale: Locale(identifier: "en_US_POSIX")
          ),
          decimal > .zero,
          decimal.toSubstrateAmount(precision: Int16(maximumScale)) == exactPlanks else {
        return nil
    }

    return decimal
}

private extension String {
    func caseInsensitiveEquals(_ value: String) -> Bool {
        caseInsensitiveCompare(value) == .orderedSame
    }

    func irohaAssetMatches(_ assetId: String) -> Bool {
        self == assetId || hasPrefix("\(assetId)#")
    }
}
