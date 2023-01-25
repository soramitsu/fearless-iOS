import Foundation
import RobinHood
import CommonWallet
import IrohaCrypto
import FearlessUtils

class SubsquidHistoryOperationFactory {
    private let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    private let runtimeService: RuntimeCodingServiceProtocol

    init(
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.txStorage = txStorage
        self.runtimeService = runtimeService
    }

    private func createOperation(
        address: String,
        count: Int,
        cursor: String?,
        url: URL,
        filters: [WalletTransactionHistoryFilter]
    ) -> BaseOperation<SubsquidHistoryResponse> {
        let queryString = prepareQueryForAddress(
            address,
            count: count,
            cursor: cursor,
            filters: filters
        )

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubsquidHistoryResponse> { data in
            do {
                let response = try JSONDecoder().decode(
                    SubqueryResponse<SubsquidHistoryResponse>.self,
                    from: data
                )

                switch response {
                case let .errors(error):
                    throw error
                case let .data(response):
                    return response
                }
            } catch {
                throw error
            }
        }

        let operation = NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )

        return operation
    }

    private func prepareExtrinsicInclusionFilter() -> String {
        """
        {
          or: [
            {
                  extrinsic: {isNull: true}
            },
            {
              not: {
                and: [
                    {
                      extrinsic: { contains: {module: "balances"} } ,
                        or: [
                         { extrinsic: {contains: {call: "transfer"} } },
                         { extrinsic: {contains: {call: "transferKeepAlive"} } },
                         { extrinsic: {contains: {call: "forceTransfer"} } },
                      ]
                    }
                ]
               }
            }
          ]
        }
        """
    }

    private func prepareFilter(
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        var filterStrings: [String] = []

        if !filters.contains(where: { $0.type == .other && $0.selected }) {
            filterStrings.append("extrinsic_isNull: true")
        }

        if !filters.contains(where: { $0.type == .reward && $0.selected }) {
            filterStrings.append("reward_isNull: true")
        }

        if !filters.contains(where: { $0.type == .transfer && $0.selected }) {
            filterStrings.append("transfer_isNull: true")
        }

        return filterStrings.joined(separator: ",")
    }

    private func prepareQueryForAddress(
        _ address: String,
        count _: Int,
        cursor: String?,
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        let after = cursor.map { "\"\($0)\"" } ?? "null"
        let filterString = prepareFilter(filters: filters)
        return """
        query MyQuery {
          historyElements(where: {address_eq: "\(address)", \(filterString)}, orderBy: timestamp_DESC) {
            timestamp
            id
            extrinsicIdx
            extrinsicHash
            blockNumber
            address
                                    extrinsic {
                                      call
                                      fee
                                      hash
                                      module
                                      success
                                    }
                    transfer {
                    amount
                    eventIdx
                    fee
                    from
                    success
                    to
                    }
                                reward {
                                  amount
                                  era
                                  eventIdx
                                  isReward
                                  stash
                                  validator
                                }
          }
        }
        """
    }

    private func createHistoryMergeOperation(
        dependingOn remoteOperation: BaseOperation<WalletRemoteHistoryData>?,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        asset: AssetModel,
        chain: ChainModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation?.extractNoCancellableResultData().historyItems ?? []

            if let localTransactions = try localOperation?.extractNoCancellableResultData(),
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

    private func createSubqueryHistoryMergeOperation(
        dependingOn remoteOperation: BaseOperation<SubsquidHistoryResponse>?,
        runtimeOperation _: BaseOperation<RuntimeCoderFactoryProtocol>,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        asset: AssetModel,
        chain: ChainModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        return ClosureOperation {
            let remoteTransactions = try remoteOperation?.extractNoCancellableResultData().historyElements ?? []
            let filteredTransactions = remoteTransactions.sorted { element1, element2 in
                element2.timestampInSeconds < element1.timestampInSeconds
            }
//            try remoteTransactions.filter { transaction in
//                var assetId: String?
//
//                if let transfer = transaction.transfer {
//                    assetId = transfer.assetId
//                } else if let reward = transaction.reward {
//                    assetId = reward.assetId
//                } else if let extrinsic = transaction.extrinsic {
//                    assetId = extrinsic.assetId
//                }
//
//                if chainAsset.chainAssetType != .normal, assetId == nil {
//                    return false
//                }
//
//                if chainAsset.chainAssetType == .normal, assetId != nil {
//                    return false
//                }
//
//                if chainAsset.chainAssetType == .normal, assetId == nil {
//                    return true
//                }
//
//                guard let assetId = assetId else {
//                    return false
//                }
//
//                let assetIdBytes = try Data(hexString: assetId)
//                let encoder = try runtimeOperation.extractNoCancellableResultData().createEncoder()
//                guard let currencyId = chainAsset.currencyId else {
//                    return false
//                }
//
//                guard let type = try runtimeOperation.extractNoCancellableResultData().metadata.schema?.types
//                    .first(where: { $0.type.path.contains("CurrencyId") })?
//                    .type
//                    .path
//                    .joined(separator: "::")
//                else {
//                    return false
//                }
//                try encoder.append(currencyId, ofType: type)
//                let currencyIdBytes = try encoder.encode()
//
//                return currencyIdBytes == assetIdBytes
//            }

            if let localTransactions = try localOperation?.extractNoCancellableResultData(),
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
                let transactions: [AssetTransactionData] = filteredTransactions.map { item in
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

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: !newHistoryContext.isComplete ? newHistoryContext.toContext() : nil
            )
        }
    }

    private func createSubqueryHistoryMapOperation(
        dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>,
        remoteOperation: BaseOperation<SubsquidHistoryResponse>
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()
            let remoteData = try remoteOperation.extractNoCancellableResultData()

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: [:]
            )
        }
    }
}

extension SubsquidHistoryOperationFactory: HistoryOperationFactoryProtocol {
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

        let remoteHistoryOperation: BaseOperation<SubsquidHistoryResponse>

        if let baseUrl = chain.externalApi?.history?.url {
            remoteHistoryOperation = createOperation(
                address: address,
                count: pagination.count,
                cursor: pagination.context?["endCursor"],
                url: baseUrl,
                filters: filters
            )
        } else {
            let context = TransactionHistoryContext(context: [:], defaultRow: 0)
            let result = SubsquidHistoryResponse(historyElements: [])
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
}
