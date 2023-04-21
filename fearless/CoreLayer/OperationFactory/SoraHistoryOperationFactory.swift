import CommonWallet
import RobinHood
import IrohaCrypto
import SSFUtils
import XNetworking
import BigInt

final class SoraHistoryOperationFactory: HistoryOperationFactoryProtocol {
    private let txStorage: AnyDataProviderRepository<TransactionHistoryItem>

    init(txStorage: AnyDataProviderRepository<TransactionHistoryItem>) {
        self.txStorage = txStorage
    }

    // MARK: - Public methods

    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let historyContext = TransactionHistoryContext(
            context: pagination.context ?? [:],
            defaultRow: pagination.count
        ).byApplying(filters: filters)

        let isCompletedString = pagination.context?[TransactionHistoryContext.isComplete] ?? ""
        let isCompleted = Bool(isCompletedString) ?? false
        guard !isCompleted else {
            let pageData = AssetTransactionPageData(
                transactions: [],
                context: nil
            )

            let operation = BaseOperation<AssetTransactionPageData?>()
            operation.result = .success(pageData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        var cursor = 1
        if let stringCursor = pagination.context?[TransactionHistoryContext.cursor] {
            cursor = Int(stringCursor) ?? 1
        }

        let remoteHistoryWrapper: CompoundOperationWrapper<WalletRemoteHistoryData>
        if let baseUrl = chain.externalApi?.history?.url {
            remoteHistoryWrapper = createSoraOperationWrapper(
                chainAsset: chainAsset,
                baseURL: baseUrl,
                for: historyContext,
                address: address,
                count: pagination.count,
                cursor: cursor,
                filters: filters
            )
        } else {
            let result = WalletRemoteHistoryData(historyItems: [], context: historyContext)
            remoteHistoryWrapper = CompoundOperationWrapper.createWithResult(result)
        }

        var dependencies = remoteHistoryWrapper.allOperations

        let localFetchOperation: BaseOperation<[TransactionHistoryItem]>?

        if pagination.context == nil {
            let operation = txStorage.fetchAllOperation(with: RepositoryFetchOptions())
            dependencies.append(operation)

            remoteHistoryWrapper.allOperations.forEach { operation.addDependency($0) }

            localFetchOperation = operation
        } else {
            localFetchOperation = nil
        }

        let mergeOperation = createHistoryMergeOperation(
            dependingOn: remoteHistoryWrapper,
            localOperation: localFetchOperation,
            asset: asset,
            chain: chain,
            address: address
        )

        dependencies.forEach { mergeOperation.addDependency($0) }

        dependencies.append(mergeOperation)

        if pagination.context == nil {
            let clearOperation = txStorage.saveOperation({ [] }, {
                let mergeResult = try mergeOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                return mergeResult.identifiersToRemove
            })

            dependencies.append(clearOperation)
            clearOperation.addDependency(mergeOperation)
        }

        let mapOperation = createHistoryMapOperation(
            dependingOn: mergeOperation,
            remoteOperation: remoteHistoryWrapper.targetOperation
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    // MARK: - Private methods

    private func createSoraOperationWrapper(
        chainAsset: ChainAsset,
        baseURL: URL,
        for context: TransactionHistoryContext,
        address: String,
        count: Int,
        cursor: Int,
        filters: [WalletTransactionHistoryFilter]
    ) -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        let queryOperation = SoraXNetworkingHistoryOperation<TxHistoryResult<TxHistoryItem>>(
            chainAsset: chainAsset,
            filters: filters,
            url: baseURL,
            address: address,
            count: count,
            page: cursor
        )

        let mappingOperation = ClosureOperation<WalletRemoteHistoryData> {
            guard let response = try? queryOperation.extractNoCancellableResultData() else {
                return WalletRemoteHistoryData(historyItems: [], context: context)
            }

            let isCompleted = response.endReached
            let items = (response.items as? [WalletRemoteHistoryItemProtocol]) ?? []
            var updatedContext = context
            updatedContext.soraCursor = (context.soraCursor ?? 1) + 1
            updatedContext.soraIsComplete = isCompleted

            return WalletRemoteHistoryData(
                historyItems: items,
                context: updatedContext
            )
        }

        mappingOperation.addDependency(queryOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [queryOperation])
    }

    private func createHistoryMergeOperation(
        dependingOn remoteOperation: CompoundOperationWrapper<WalletRemoteHistoryData>?,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        asset: AssetModel,
        chain: ChainModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation?
                .targetOperation
                .extractNoCancellableResultData()
                .historyItems ?? []

            if let localTransactions = try localOperation?.extractNoCancellableResultData()
                .filter({ $0.sender == address || $0.receiver == address }),
                !localTransactions.isEmpty {
                let manager = TransactionHistoryMergeManager(
                    address: address,
                    chain: chain,
                    asset: asset
                )
                return manager.merge(
                    subscanItems: remoteTransactions,
                    localItems: localTransactions
                )
            } else {
                let transactions: [AssetTransactionData] = remoteTransactions.map { item in
                    item.createTransactionForAddress(
                        address,
                        chain: chain,
                        asset: asset
                    )
                }

                return TransactionHistoryMergeResult(
                    historyItems: transactions,
                    identifiersToRemove: []
                )
            }
        }
    }

    private func createHistoryMapOperation(
        dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>,
        remoteOperation: BaseOperation<WalletRemoteHistoryData>
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()
            let newHistoryContext = try remoteOperation.extractNoCancellableResultData().context

            let contextDict = [TransactionHistoryContext.isComplete: String(newHistoryContext.soraIsComplete),
                               TransactionHistoryContext.cursor: String(newHistoryContext.soraCursor ?? 1)]
            let context = !newHistoryContext.isComplete ? contextDict : nil

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: context
            )
        }
    }
}
