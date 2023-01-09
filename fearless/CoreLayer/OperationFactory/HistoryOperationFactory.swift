import CommonWallet
import RobinHood
import IrohaCrypto
import FearlessUtils

protocol HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?>

    func fetchSubqueryHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?>
}

class HistoryOperationFactory: HistoryOperationFactoryProtocol {
    private let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    private let runtimeService: RuntimeCodingServiceProtocol

    init(
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.txStorage = txStorage
        self.runtimeService = runtimeService
    }

    func fetchSubqueryHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        let historyContext = TransactionHistoryContext(
            context: pagination.context ?? [:],
            defaultRow: pagination.count
        ).byApplying(filters: filters)

        guard !historyContext.isComplete else {
            let pageData = AssetTransactionPageData(
                transactions: [],
                context: nil
            )

            let operation = BaseOperation<AssetTransactionPageData?>()
            operation.result = .success(pageData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let remoteHistoryOperation: BaseOperation<SubqueryHistoryData>

        if let baseUrl = chain.externalApi?.history?.url {
            let remoteHistoryFactory = SubqueryHistoryOperationFactory(
                url: baseUrl,
                filters: filters
            )

            remoteHistoryOperation = remoteHistoryFactory.createOperation(
                address: address,
                count: pagination.count,
                cursor: pagination.context?["endCursor"]
            )
        } else {
            let context = TransactionHistoryContext(context: [:], defaultRow: 0)
            let result = SubqueryHistoryData(historyElements: SubqueryHistoryData.HistoryElements(pageInfo: SubqueryPageInfo(startCursor: nil, endCursor: nil), nodes: []))
            remoteHistoryOperation = BaseOperation.createWithResult(result)
        }

        var dependencies: [Operation] = [remoteHistoryOperation, runtimeOperation]

        let localFetchOperation: BaseOperation<[TransactionHistoryItem]>?

        if pagination.context == nil {
            let operation = txStorage.fetchAllOperation(with: RepositoryFetchOptions())
            dependencies.append(operation)

            operation.addDependency(remoteHistoryOperation)

            localFetchOperation = operation
        } else {
            localFetchOperation = nil
        }

        let mergeOperation = createSubqueryHistoryMergeOperation(
            dependingOn: remoteHistoryOperation,
            runtimeOperation: runtimeOperation,
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

        let mapOperation = createSubqueryHistoryMapOperation(
            dependingOn: mergeOperation,
            remoteOperation: remoteHistoryOperation
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let historyContext = TransactionHistoryContext(
            context: pagination.context ?? [:],
            defaultRow: pagination.count
        ).byApplying(filters: filters)

        guard !historyContext.isComplete else {
            let pageData = AssetTransactionPageData(
                transactions: [],
                context: nil
            )

            let operation = BaseOperation<AssetTransactionPageData?>()
            operation.result = .success(pageData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let remoteHistoryWrapper: CompoundOperationWrapper<WalletRemoteHistoryData>

        if let baseUrl = chain.externalApi?.history?.url {
            let remoteHistoryFactory = SubscanHistoryOperationFactory(
                baseURL: baseUrl,
                filter: WalletRemoteHistoryClosureFilter.transfersInExtrinsics
            )

            remoteHistoryWrapper = remoteHistoryFactory.createOperationWrapper(
                for: historyContext,
                address: address,
                count: pagination.count
            )
        } else {
            let context = TransactionHistoryContext(context: [:], defaultRow: 0)
            let result = WalletRemoteHistoryData(historyItems: [], context: context)
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
            dependingOn: remoteHistoryWrapper.targetOperation,
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

    func createHistoryMergeOperation(
        dependingOn remoteOperation: BaseOperation<WalletRemoteHistoryData>?,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        asset: AssetModel,
        chain: ChainModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        let addressFactory = SS58AddressFactory()

        return ClosureOperation {
            let remoteTransactions = try remoteOperation?.extractNoCancellableResultData().historyItems ?? []

            if let localTransactions = try localOperation?.extractNoCancellableResultData(),
               !localTransactions.isEmpty {
                let manager = TransactionHistoryMergeManager(
                    address: address,
                    chain: chain,
                    asset: asset,
                    addressFactory: addressFactory
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
                        asset: asset,
                        addressFactory: addressFactory
                    )
                }

                return TransactionHistoryMergeResult(
                    historyItems: transactions,
                    identifiersToRemove: []
                )
            }
        }
    }

    func createSubqueryHistoryMergeOperation(
        dependingOn remoteOperation: BaseOperation<SubqueryHistoryData>?,
        runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        asset: AssetModel,
        chain: ChainModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        let addressFactory = SS58AddressFactory()
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        return ClosureOperation {
            let remoteTransactions = try remoteOperation?.extractNoCancellableResultData().historyElements.nodes ?? []
            let filteredTransactions = try remoteTransactions.filter { transaction in
                var assetId: String?

                if let transfer = transaction.transfer {
                    assetId = transfer.assetId
                } else if let reward = transaction.reward {
                    assetId = reward.assetId
                } else if let extrinsic = transaction.extrinsic {
                    assetId = extrinsic.assetId
                }

                if chainAsset.chainAssetType != .normal, assetId == nil {
                    return false
                }

                if chainAsset.chainAssetType == .normal, assetId != nil {
                    return false
                }

                if chainAsset.chainAssetType == .normal, assetId == nil {
                    return true
                }

                guard let assetId = assetId else {
                    return false
                }

                let assetIdBytes = try Data(hexString: assetId)
                let encoder = try runtimeOperation.extractNoCancellableResultData().createEncoder()
                guard let currencyId = chainAsset.currencyId else {
                    return false
                }

                guard let type = try runtimeOperation.extractNoCancellableResultData().metadata.schema?.types
                    .first(where: { $0.type.path.contains("CurrencyId") })?
                    .type
                    .path
                    .joined(separator: "::")
                else {
                    return false
                }
                try encoder.append(currencyId, ofType: type)
                let currencyIdBytes = try encoder.encode()

                return currencyIdBytes == assetIdBytes
            }

            if let localTransactions = try localOperation?.extractNoCancellableResultData(),
               !localTransactions.isEmpty {
                let manager = TransactionHistoryMergeManager(
                    address: address,
                    chain: chain,
                    asset: asset,
                    addressFactory: addressFactory
                )
                return manager.merge(
                    subscanItems: remoteTransactions,
                    localItems: localTransactions
                )
            } else {
                let transactions: [AssetTransactionData] = filteredTransactions.map { item in
                    item.createTransactionForAddress(
                        address,
                        chain: chain,
                        asset: asset,
                        addressFactory: addressFactory
                    )
                }

                return TransactionHistoryMergeResult(
                    historyItems: transactions,
                    identifiersToRemove: []
                )
            }
        }
    }

    func createHistoryMapOperation(
        dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>,
        remoteOperation: BaseOperation<WalletRemoteHistoryData>
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()
            let newHistoryContext = try remoteOperation.extractNoCancellableResultData().context

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: !newHistoryContext.isComplete ? newHistoryContext.toContext() : nil
            )
        }
    }

    func createSubqueryHistoryMapOperation(
        dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>,
        remoteOperation: BaseOperation<SubqueryHistoryData>
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()
            let remoteData = try remoteOperation.extractNoCancellableResultData()

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: remoteData.historyElements.pageInfo.toContext()
            )
        }
    }
}
