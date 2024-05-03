import Foundation
import RobinHood

import IrohaCrypto
import SSFUtils
import SSFModels

final class SubsquidHistoryOperationFactory {
    private let txStorage: AnyDataProviderRepository<TransactionHistoryItem>

    init(
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    ) {
        self.txStorage = txStorage
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
                    GraphQLResponse<SubsquidHistoryResponse>.self,
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
        count: Int,
        cursor: String?,
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        let filterString = prepareFilter(filters: filters)
        let offset: Int = cursor.map { Int($0) ?? 0 } ?? 0
        return """
        query MyQuery {
          historyElements(where: {address_eq: "\(address)", \(filterString)}, orderBy: timestamp_DESC, limit: \(count), offset: \(offset)) {
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
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        asset: AssetModel,
        chain: ChainModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation?.extractNoCancellableResultData().historyElements ?? []
            let filteredTransactions = remoteTransactions.sorted { element1, element2 in
                element2.timestampInSeconds < element1.timestampInSeconds
            }

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
        remoteOperation _: BaseOperation<SubsquidHistoryResponse>,
        pagination: Pagination
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let context = pagination.context
            let endCursor = context.map { (Int($0["endCursor"] ?? "0") ?? 0) + pagination.count } ?? pagination.count

            let mergeResult = try mergeOperation.extractNoCancellableResultData()

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: ["endCursor": "\(endCursor)"]
            )
        }
    }
}

extension SubsquidHistoryOperationFactory: HistoryOperationFactoryProtocol {
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
            let result = SubsquidHistoryResponse(historyElements: [])
            remoteHistoryOperation = BaseOperation.createWithResult(result)
        }

        var dependencies: [Operation] = [remoteHistoryOperation]

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
            remoteOperation: remoteHistoryOperation,
            pagination: pagination
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
