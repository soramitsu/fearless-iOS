import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFUtils

final class BitcoinHistoryOperationFactory {
    static let paginationLastSeenTxidKey = "lastSeenTxid"

    private static let supportedChainIds: Set<String> = [
        UniversalWalletRegistry.bitcoinMainnet.chainId,
        UniversalWalletRegistry.bitcoinMainnet.id,
        UniversalWalletRegistry.bitcoinTestnet.chainId,
        UniversalWalletRegistry.bitcoinTestnet.id
    ]

    private let sync: BitcoinTransactionHistorySync

    init(client: BitcoinIndexerClientProtocol = BitcoinIndexerClient()) {
        sync = BitcoinTransactionHistorySync(client: client)
    }

    static func supports(chain: ChainModel) -> Bool {
        supportedChainIds.contains(chain.chainId.lowercased())
    }

    private func network(for chain: ChainModel) -> BitcoinIndexerNetwork {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.bitcoinTestnet.chainId, UniversalWalletRegistry.bitcoinTestnet.id:
            return .testnet
        default:
            return .mainnet
        }
    }

    private func historyBaseURL(for chain: ChainModel) -> String? {
        chain.externalApi?.history?.url.absoluteString
    }

    private func isSupportedBitcoinAsset(_ asset: AssetModel) -> Bool {
        asset.id.uppercased() == UniversalWalletRegistry.bitcoinMainnet.nativeAsset.id &&
            asset.symbol.uppercased() == UniversalWalletRegistry.bitcoinMainnet.nativeAsset.symbol &&
            asset.precision == UInt16(UniversalWalletRegistry.bitcoinMainnet.nativeAsset.decimals)
    }

    private func shouldFetch(filters: [WalletTransactionHistoryFilter]) -> Bool {
        filters.isEmpty || filters.contains { $0.type == .transfer && $0.selected }
    }

    private func createHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        pagination: Pagination
    ) -> BaseOperation<AssetTransactionPageData?> {
        AwaitOperation { [sync] in
            do {
                let page = try await self.fetchBitcoinHistoryPage(
                    sync: sync,
                    asset: asset,
                    chain: chain,
                    address: address,
                    pagination: pagination
                )

                return page
            } catch {
                return AssetTransactionPageData(transactions: [])
            }
        }
    }

    private func fetchBitcoinHistoryPage(
        sync: BitcoinTransactionHistorySync,
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        pagination: Pagination
    ) async throws -> AssetTransactionPageData {
        let requestedCount = pagination.count
        let page = try await sync.historyWindow(
            address: address,
            network: network(for: chain),
            baseURL: historyBaseURL(for: chain),
            lastSeenTxid: pagination.context?[Self.paginationLastSeenTxidKey]
        )

        let visibleEntries = Array(page.entries.prefix(requestedCount))
        let nextContext: PaginationContext?
        if page.entries.count > visibleEntries.count, let lastVisibleTxid = visibleEntries.last?.txid {
            nextContext = [Self.paginationLastSeenTxidKey: lastVisibleTxid]
        } else {
            nextContext = nil
        }

        return AssetTransactionPageData(
            transactions: visibleEntries.map { transactionData(from: $0, asset: asset) },
            context: nextContext
        )
    }

    private func transactionData(
        from entry: BitcoinTransactionHistoryEntry,
        asset: AssetModel
    ) -> AssetTransactionData {
        let amount = decimalFromSats(entry.amountSats, precision: asset.precision)
        let peerAddress = entry.outgoing ? entry.to : entry.from
        let fee = feeData(from: entry, asset: asset)
        let type: TransactionType = entry.outgoing ? .outgoing : .incoming

        return AssetTransactionData(
            transactionId: entry.txid,
            status: entry.confirmed ? .commited : .pending,
            assetId: asset.id,
            peerId: peerAddress,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: fee.map { [$0] } ?? [],
            timestamp: entry.timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }

    private func feeData(
        from entry: BitcoinTransactionHistoryEntry,
        asset: AssetModel
    ) -> AssetTransactionFee? {
        guard entry.outgoing, entry.feeSats > 0 else {
            return nil
        }

        let amount = decimalFromSats(entry.feeSats, precision: asset.precision)
        return AssetTransactionFee(
            identifier: asset.id,
            assetId: asset.id,
            amount: AmountDecimal(value: amount),
            context: nil
        )
    }

    private func decimalFromSats(_ sats: Int64, precision: UInt16) -> Decimal {
        guard sats > 0, precision <= UInt16(Int16.max), let value = BigUInt(String(sats)) else {
            return .zero
        }

        return Decimal.fromSubstrateAmount(value, precision: Int16(precision)) ?? .zero
    }

    private func emptyPage() -> CompoundOperationWrapper<AssetTransactionPageData?> {
        CompoundOperationWrapper.createWithResult(AssetTransactionPageData(transactions: []))
    }
}

extension BitcoinHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard
            pagination.count >= 1,
            isSupportedBitcoinAsset(asset),
            shouldFetch(filters: filters)
        else {
            return emptyPage()
        }

        let historyOperation = createHistoryOperation(
            asset: asset,
            chain: chain,
            address: address,
            pagination: pagination
        )

        return CompoundOperationWrapper(targetOperation: historyOperation)
    }
}
