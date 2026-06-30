import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFUtils

final class SolanaHistoryOperationFactory {
    static let paginationCursorKey = "before"

    private let sync: SolanaTransactionHistorySync

    init(client: SolanaIndexerClientProtocol = SolanaIndexerClient()) {
        sync = SolanaTransactionHistorySync(client: client)
    }

    static func supports(chain: ChainModel) -> Bool {
        network(for: chain) != nil
    }

    private static func network(for chain: ChainModel) -> UniversalWalletRegistry.SolanaNetwork? {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaMainnet.id:
            return UniversalWalletRegistry.solanaMainnet
        case UniversalWalletRegistry.solanaDevnet.chainId, UniversalWalletRegistry.solanaDevnet.id:
            return UniversalWalletRegistry.solanaDevnet
        default:
            return nil
        }
    }

    private func historyBaseURL(for chain: ChainModel) -> String? {
        chain.externalApi?.history?.url.absoluteString
    }

    private func solanaHistoryAsset(
        for asset: AssetModel,
        network: UniversalWalletRegistry.SolanaNetwork
    ) -> SolanaHistoryAsset? {
        if asset.id.uppercased() == network.nativeAsset.id,
           asset.symbol.uppercased() == network.nativeAsset.symbol,
           asset.precision == UInt16(network.nativeAsset.decimals),
           asset.isNative {
            return SolanaHistoryAsset(assetId: network.nativeAsset.id, isNative: true)
        }

        guard !asset.isNative, !asset.id.isEmpty, asset.id != network.nativeAsset.id else {
            return nil
        }

        return SolanaHistoryAsset(assetId: asset.id, isNative: false)
    }

    private func shouldFetch(filters: [WalletTransactionHistoryFilter]) -> Bool {
        filters.isEmpty || filters.contains { $0.type == .transfer && $0.selected }
    }

    private func createHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        network: UniversalWalletRegistry.SolanaNetwork,
        historyAsset: SolanaHistoryAsset,
        address: String,
        pagination: Pagination
    ) -> BaseOperation<AssetTransactionPageData?> {
        AwaitOperation { [sync] in
            do {
                return try await self.fetchSolanaHistoryPage(
                    sync: sync,
                    asset: asset,
                    chain: chain,
                    network: network,
                    historyAsset: historyAsset,
                    address: address,
                    pagination: pagination
                )
            } catch {
                return AssetTransactionPageData(transactions: [])
            }
        }
    }

    private func fetchSolanaHistoryPage(
        sync: SolanaTransactionHistorySync,
        asset: AssetModel,
        chain: ChainModel,
        network: UniversalWalletRegistry.SolanaNetwork,
        historyAsset: SolanaHistoryAsset,
        address: String,
        pagination: Pagination
    ) async throws -> AssetTransactionPageData {
        let limit = min(pagination.count, SolanaIndexerRoutes.maxLimit)
        let page = try await sync.history(
            wallet: address,
            assetId: historyAsset.assetId,
            isNative: historyAsset.isNative,
            network: network,
            baseURL: historyBaseURL(for: chain),
            before: pagination.context?[Self.paginationCursorKey],
            limit: limit
        )

        let transactions = page.transactions
            .filter { $0.operationType == .transfer }
            .compactMap {
                transactionData(
                    from: $0,
                    asset: asset,
                    network: network,
                    historyAsset: historyAsset
                )
            }

        let nextContext = page.pageInfo.nextCursor.map { [Self.paginationCursorKey: $0] }
        return AssetTransactionPageData(transactions: transactions, context: nextContext)
    }

    private func transactionData(
        from entry: UniversalWalletIndexedTransaction,
        asset: AssetModel,
        network: UniversalWalletRegistry.SolanaNetwork,
        historyAsset: SolanaHistoryAsset
    ) -> AssetTransactionData? {
        guard
            entry.assetId == historyAsset.assetId,
            let amount = decimalFromRawAmount(entry.amount, precision: asset.precision),
            let timestampMillis = entry.timestampMillis
        else {
            return nil
        }

        let type: TransactionType
        switch entry.direction {
        case .incoming:
            type = .incoming
        case .outgoing:
            type = .outgoing
        case .self, .unknown:
            return nil
        }

        let status: AssetTransactionStatus
        switch entry.status {
        case .confirmed:
            status = .commited
        case .pending:
            status = .pending
        case .failed:
            status = .rejected
        }

        let peerAddress = entry.counterpartyAddress ?? ""

        return AssetTransactionData(
            transactionId: entry.transactionId,
            status: status,
            assetId: asset.id,
            peerId: peerAddress,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress.isEmpty ? nil : peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: feeData(
                from: entry,
                network: network,
                asset: asset,
                includeNativeFee: historyAsset.isNative
            ).map { [$0] } ?? [],
            timestamp: timestampMillis / 1000,
            type: type.rawValue,
            reason: "",
            context: entry.cursor.map { [Self.paginationCursorKey: $0] }
        )
    }

    private func feeData(
        from entry: UniversalWalletIndexedTransaction,
        network: UniversalWalletRegistry.SolanaNetwork,
        asset: AssetModel,
        includeNativeFee: Bool
    ) -> AssetTransactionFee? {
        guard
            includeNativeFee,
            entry.direction == .outgoing,
            entry.feeAssetId == network.nativeAsset.id,
            let amount = decimalFromRawAmount(entry.feeAmount, precision: asset.precision),
            !amount.isZero
        else {
            return nil
        }

        return AssetTransactionFee(
            identifier: asset.id,
            assetId: asset.id,
            amount: AmountDecimal(value: amount),
            context: nil
        )
    }

    private func decimalFromRawAmount(_ value: String?, precision: UInt16) -> Decimal? {
        guard
            let value,
            precision <= UInt16(Int16.max),
            let amount = BigUInt(value)
        else {
            return nil
        }

        return Decimal.fromSubstrateAmount(amount, precision: Int16(precision))
    }

    private func emptyPage() -> CompoundOperationWrapper<AssetTransactionPageData?> {
        CompoundOperationWrapper.createWithResult(AssetTransactionPageData(transactions: []))
    }
}

extension SolanaHistoryOperationFactory: HistoryOperationFactoryProtocol {
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
            shouldFetch(filters: filters)
        else {
            return emptyPage()
        }

        guard let historyAsset = solanaHistoryAsset(for: asset, network: network) else {
            return emptyPage()
        }

        let historyOperation = createHistoryOperation(
            asset: asset,
            chain: chain,
            network: network,
            historyAsset: historyAsset,
            address: address,
            pagination: pagination
        )

        return CompoundOperationWrapper(targetOperation: historyOperation)
    }
}

private struct SolanaHistoryAsset {
    let assetId: String
    let isNative: Bool
}
