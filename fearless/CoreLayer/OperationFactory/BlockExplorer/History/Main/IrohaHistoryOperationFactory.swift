import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFUtils

final class IrohaHistoryOperationFactory {
    static let paginationPageKey = "page"

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

    private func historyBaseURL(for chain: ChainModel) -> String? {
        chain.externalApi?.history?.url.absoluteString
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
        AwaitOperation { [client] in
            do {
                return try await self.fetchIrohaHistoryPage(
                    client: client,
                    asset: asset,
                    chain: chain,
                    network: network,
                    address: address,
                    pagination: pagination
                )
            } catch {
                return AssetTransactionPageData(transactions: [])
            }
        }
    }

    private func fetchIrohaHistoryPage(
        client: IrohaToriiClientProtocol,
        asset: AssetModel,
        chain: ChainModel,
        network: UniversalWalletRegistry.IrohaNetwork,
        address: String,
        pagination: Pagination
    ) async throws -> AssetTransactionPageData {
        let page = pagination.context?[Self.paginationPageKey]
            .flatMap { Int($0) }
            .flatMap { $0 >= 0 ? $0 : nil } ?? 0
        let limit = min(pagination.count, IrohaToriiRoutes.maxLimit)
        let request = try IrohaToriiRoutes.mcpJSONRPCRequest(
            method: "tools/call",
            id: "history-\(page)",
            params: [
                "name": .string("iroha.instructions.list"),
                "arguments": .object([
                    "account": .string(address),
                    "asset_id": .string(asset.id),
                    "kind": .string("Transfer"),
                    "page": .int(Int64(page)),
                    "per_page": .int(Int64(limit)),
                    "transaction_status": .string("committed"),
                    "accept": .string("application/json")
                ])
            ]
        )
        let response = try await client.mcpJSONRPC(
            request,
            network: network,
            baseURL: historyBaseURL(for: chain)
        )

        guard response.error == nil else {
            return AssetTransactionPageData(transactions: [])
        }

        let items = response.result.instructionItems()
        let transactions = items.enumerated().flatMap { index, item in
            item.transactionData(index: index, accountAddress: address, asset: asset)
        }
        let nextContext = items.count >= limit ? [Self.paginationPageKey: String(page + 1)] : nil

        return AssetTransactionPageData(transactions: transactions, context: nextContext)
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

private extension IrohaJSONValue? {
    func instructionItems() -> [[String: IrohaJSONValue]] {
        guard let result = self?.objectValue else {
            return []
        }

        let body = result["body"]?.objectValue ?? result
        return body["items"]?.arrayValue?.compactMap(\.objectValue) ?? []
    }
}

private extension [String: IrohaJSONValue] {
    func transactionData(
        index: Int,
        accountAddress: String,
        asset: AssetModel
    ) -> [AssetTransactionData] {
        guard
            let hash = stringValue("transaction_hash", "transactionHash", "hash"),
            let timestamp = timestampSeconds(stringValue("created_at", "createdAt", "timestamp")),
            let payload = self["box"]?.objectValue?["json"]?.objectValue?["payload"]?.objectValue
        else {
            return []
        }

        let status: AssetTransactionStatus = stringValue("transaction_status", "transactionStatus", "status")
            .caseInsensitiveEquals("Rejected") ? .rejected : .commited
        let transfers = payload.transferPayloads(accountAddress: accountAddress, assetId: asset.id)

        return transfers.enumerated().compactMap { transferIndex, transfer in
            guard
                asset.precision <= UInt16(Int16.max),
                let amount = Decimal.fromSubstrateAmount(transfer.amount, precision: Int16(asset.precision))
            else {
                return nil
            }

            let isOutgoing = transfer.from.caseInsensitiveEquals(accountAddress)
            let peerAddress = isOutgoing ? transfer.to : transfer.from

            return AssetTransactionData(
                transactionId: transfers.count == 1 ? hash : "\(hash):\(index + transferIndex)",
                status: status,
                assetId: asset.id,
                peerId: peerAddress,
                peerFirstName: nil,
                peerLastName: nil,
                peerName: peerAddress.isEmpty ? nil : peerAddress,
                details: "",
                amount: AmountDecimal(value: amount),
                fees: [],
                timestamp: timestamp,
                type: (isOutgoing ? TransactionType.outgoing : .incoming).rawValue,
                reason: "",
                context: nil
            )
        }
    }

    func transferPayloads(accountAddress: String, assetId: String) -> [IrohaTransferPayload] {
        guard let variant = stringValue("variant") else {
            return []
        }

        switch variant {
        case "Asset":
            return self["value"]?.objectValue?.assetTransfer(accountAddress: accountAddress, assetId: assetId).map { [$0] } ?? []
        case "AssetBatch":
            let value = self["value"]?.objectValue
            let entries = value?.firstArray("entries", "transfers", "items") ?? self["value"]?.arrayValue
            return entries?.compactMap {
                $0.objectValue?.assetTransfer(accountAddress: accountAddress, assetId: assetId)
            } ?? []
        default:
            return []
        }
    }

    func assetTransfer(accountAddress: String, assetId: String) -> IrohaTransferPayload? {
        let source = stringValue("source", "source_id", "asset", "asset_id")
        guard
            let destination = stringValue("destination", "destination_id", "to", "account_id"),
            let amount = normalizeIrohaAmount(self["object"] ?? self["amount"] ?? self["quantity"] ?? self["value"])
        else {
            return nil
        }

        if let source, !source.irohaAssetMatches(assetId) {
            return nil
        }

        let sourceAccount = stringValue("source_account", "from", "account") ?? source?.extractIrohaAssetAccount()
        let incoming = destination.caseInsensitiveEquals(accountAddress)
        let outgoing = sourceAccount?.caseInsensitiveEquals(accountAddress) == true || source?.contains(accountAddress) == true

        guard incoming || outgoing else {
            return nil
        }

        return IrohaTransferPayload(
            amount: amount,
            from: outgoing ? accountAddress : sourceAccount ?? "",
            to: incoming ? accountAddress : destination
        )
    }

    func stringValue(_ keys: String...) -> String? {
        for key in keys {
            if let value = self[key]?.trimmedString {
                return value
            }
        }

        return nil
    }

    func firstArray(_ keys: String...) -> [IrohaJSONValue]? {
        for key in keys {
            if let value = self[key]?.arrayValue {
                return value
            }
        }

        return nil
    }
}

private extension IrohaJSONValue {
    var objectValue: [String: IrohaJSONValue]? {
        if case let .object(value) = self {
            return value
        }

        return nil
    }

    var arrayValue: [IrohaJSONValue]? {
        if case let .array(value) = self {
            return value
        }

        return nil
    }

    var trimmedString: String? {
        guard case let .string(value) = self else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func normalizeIrohaAmount(_ value: IrohaJSONValue?) -> BigUInt? {
    switch value {
    case let .string(raw):
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard unsignedIntegerRegex.firstMatch(
            in: trimmed,
            range: NSRange(trimmed.startIndex..., in: trimmed)
        ) != nil else {
            return nil
        }

        return BigUInt(trimmed)
    case let .int(value):
        return value > 0 ? BigUInt(UInt64(value)) : nil
    case let .double(value):
        guard value > 0, value <= Double(Int64.max), value.rounded(.towardZero) == value else {
            return nil
        }

        return BigUInt(String(Int64(value)))
    case let .object(value):
        if let scale = value["scale"], !scale.isZeroScale {
            return nil
        }

        return normalizeIrohaAmount(value["value"] ?? value["amount"] ?? value["mantissa"])
    default:
        return nil
    }
}

private extension IrohaJSONValue {
    var isZeroScale: Bool {
        switch self {
        case let .string(value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines) == "0"
        case let .int(value):
            return value == 0
        case let .double(value):
            return value == 0
        default:
            return false
        }
    }
}

private func timestampSeconds(_ value: String?) -> Int64? {
    guard let value else {
        return nil
    }

    if value.allSatisfy(\.isNumber) {
        guard let raw = Int64(value) else {
            return nil
        }

        return raw < millisThreshold ? raw : raw / 1000
    }

    return iso8601DateFormatter.date(from: value).map { Int64($0.timeIntervalSince1970) }
}

private extension String? {
    func caseInsensitiveEquals(_ value: String) -> Bool {
        self?.caseInsensitiveCompare(value) == .orderedSame
    }
}

private extension String {
    func caseInsensitiveEquals(_ value: String) -> Bool {
        caseInsensitiveCompare(value) == .orderedSame
    }

    func extractIrohaAssetAccount() -> String? {
        guard let index = lastIndex(of: "#"), index < self.index(before: endIndex) else {
            return nil
        }

        return String(self[self.index(after: index)...])
    }

    func irohaAssetMatches(_ assetId: String) -> Bool {
        self == assetId || hasPrefix("\(assetId)#")
    }
}

private struct IrohaTransferPayload {
    let amount: BigUInt
    let from: String
    let to: String
}

private let millisThreshold: Int64 = 10_000_000_000
private let unsignedIntegerRegex = try! NSRegularExpression(pattern: "^[1-9][0-9]*$")
private let iso8601DateFormatter = ISO8601DateFormatter()
