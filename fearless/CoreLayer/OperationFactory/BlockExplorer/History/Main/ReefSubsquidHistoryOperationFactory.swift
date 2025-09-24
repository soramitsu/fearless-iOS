import Foundation
import RobinHood

import IrohaCrypto
import SSFUtils
import SSFModels
import SoraFoundation

final class ReefSubsquidHistoryOperationFactory {
    private let txStorage: AnyDataProviderRepository<TransactionHistoryItem>

    init(
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    ) {
        self.txStorage = txStorage
    }

    private func createOperation(
        address: String,
        url: URL,
        filters: [WalletTransactionHistoryFilter],
        count: Int,
        transfersCursor: String?,
        stakingsCursor: String?,
        extrinsicCursor: String?
    ) -> BaseOperation<ReefResponseData> {
        let queryString = prepareQueryForAddress(
            address,
            filters: filters,
            count: count,
            transfersCursor: transfersCursor,
            stakingsCursor: stakingsCursor,
            extrinsicCursor: extrinsicCursor
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

        let resultFactory = AnyNetworkResultFactory<ReefResponseData> { data in
            do {
                let response = try JSONDecoder().decode(
                    GraphQLResponse<ReefResponseData>.self,
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
        filters: [WalletTransactionHistoryFilter],
        address: String,
        count: Int,
        transfersCursor: String?,
        stakingsCursor: String?,
        extrinsicCursor: String?
    ) -> String {
        var filterStrings: [String] = []
        let transfersAfter = transfersCursor.map { "after: \"\($0)\"" } ?? ""
        let stakingsAfter = stakingsCursor.map { "after: \"\($0)\"" } ?? ""
        let extrinsicAfter = extrinsicCursor.map { "after: \"\($0)\"" } ?? ""

        if filters.contains(where: { $0.type == .transfer && $0.selected }) {
            filterStrings.append(
                """
                transfersConnection(\(transfersAfter),
                 first: \(count), where: {AND: [{type_eq: Native}, {OR: [{from: {id_eq: "\(address)"}}, {to: {id_eq: "\(address)"}}]}]}, orderBy: timestamp_DESC) {
                    edges {
                          node {
                            amount
                            timestamp
                            success
                    extrinsicHash
                            to {
                              id
                            }
                            from {
                              id
                            }
                signedData
                blockHash
                          }
                        }
                        pageInfo {
                endCursor
                          hasNextPage
                        }
                  }
                """
            )
        }

        if filters.contains(where: { $0.type == .reward && $0.selected }) {
            filterStrings.append("""
                        stakingsConnection(\(stakingsAfter),
                 first: \(count), orderBy: timestamp_DESC, where: {AND: {signer: {id_eq: "\(address)"}, amount_gt: "0", type_eq: Reward}}) {
                                edges {
                                                                  node {
            id
                                                                    amount
                                                                    timestamp
                                                                  }
                                                                }
                                                                pageInfo {
            endCursor
                                                                  hasNextPage
                                                                }
                            }
            """)
        }

        if filters.contains(where: { $0.type == .other && $0.selected }) {
            filterStrings.append("""
                                  extrinsicsConnection(\(extrinsicAfter),
                 first: \(count), orderBy: timestamp_DESC, where: {AND: {signer_eq: "\(address)", section_not_eq: "Balances"}}) {
                                edges {
                                                                  node {
                                                                    timestamp
                                                                            signedData
                                                                            section
                                                                            method
                                                                            id
                                                                            hash
                                                                            status
                                                                            type
                                                                            signer
                                                                  }
                                                                }
                                                                pageInfo {
            endCursor
                                                                  hasNextPage
                                                                }
                            }
            """)
        }

        return filterStrings.joined(separator: "\n")
    }

    private func prepareQueryForAddress(
        _ address: String,
        filters: [WalletTransactionHistoryFilter],
        count: Int,
        transfersCursor: String?,
        stakingsCursor: String?,
        extrinsicCursor: String?
    ) -> String {
        let filterString = prepareFilter(
            filters: filters,
            address: address,
            count: count,
            transfersCursor: transfersCursor,
            stakingsCursor: stakingsCursor,
            extrinsicCursor: extrinsicCursor
        )
        return """
        query MyQuery {
          \(filterString)
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
        dependingOn remoteOperation: BaseOperation<ReefResponseData>?,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        asset: AssetModel,
        chain: ChainModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        ClosureOperation {
            let remoteTransactions: [WalletRemoteHistoryItemProtocol] = try remoteOperation?.extractNoCancellableResultData().history ?? []

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
                let transactions: [AssetTransactionData] = remoteTransactions.sorted(by: { item1, item2 in
                    item1.itemTimestamp > item2.itemTimestamp
                }).map { item in
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
        remoteOperation: BaseOperation<ReefResponseData>
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()
            let response = try remoteOperation.extractNoCancellableResultData()

            var context: [String: String] = [:]
            if let transfersCursor = response.transfersConnection?.pageInfo?.endCursor {
                context["transfersCursor"] = transfersCursor
            }

            if let stakingsCursor = response.stakingsConnection?.pageInfo?.endCursor {
                context["stakingsCursor"] = stakingsCursor
            }

            if let extrinsicCursor = response.extrinsicsConnection?.pageInfo?.endCursor {
                context["extrinsicCursor"] = extrinsicCursor
            }

            let hasNextPage = (response.transfersConnection?.pageInfo?.hasNextPage).or(false) || (response.stakingsConnection?.pageInfo?.hasNextPage).or(false)

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: hasNextPage ? context : nil
            )
        }
    }

    private func createSubqueryHistoryMapOperation(
        dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let mergeResult = try mergeOperation.extractNoCancellableResultData()

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: nil
            )
        }
    }
}

extension ReefSubsquidHistoryOperationFactory: HistoryOperationFactoryProtocol {
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

        guard !historyContext.isComplete, chainAsset.isUtility else {
            let pageData = AssetTransactionPageData(
                transactions: [],
                context: nil
            )

            let operation = BaseOperation<AssetTransactionPageData?>()
            operation.result = .success(pageData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let remoteHistoryOperation: BaseOperation<ReefResponseData>

        if let baseUrl = chain.externalApi?.history?.url {
            remoteHistoryOperation = createOperation(
                address: address,
                url: baseUrl,
                filters: filters,
                count: 20,
                transfersCursor: pagination.context?["transfersCursor"],
                stakingsCursor: pagination.context?["stakingsCursor"],
                extrinsicCursor: pagination.context?["extrinsicCursor"]
            )
        } else {
            let result = ReefResponseData(transfersConnection: nil, stakingsConnection: nil, extrinsicsConnection: nil)
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

        let mapOperation = createHistoryMapOperation(
            dependingOn: mergeOperation,
            remoteOperation: remoteHistoryOperation
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
