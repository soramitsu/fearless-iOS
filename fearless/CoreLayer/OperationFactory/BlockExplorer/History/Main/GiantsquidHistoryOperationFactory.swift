import Foundation
import RobinHood
import CommonWallet
import IrohaCrypto
import SSFUtils
import SSFModels

final class GiantsquidHistoryOperationFactory {
    private enum GiantsquidConfig {
        static let giantsquidRewardsEnabled = false
        static let giantsquidExtrinsicEnabled = false
    }

    private let txStorage: AnyDataProviderRepository<TransactionHistoryItem>

    init(
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    ) {
        self.txStorage = txStorage
    }

    private func createOperation(
        address: String,
        url: URL,
        filters: [WalletTransactionHistoryFilter]
    ) -> BaseOperation<GiantsquidResponseData> {
        let queryString = prepareQueryForAddress(
            address,
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

        let resultFactory = AnyNetworkResultFactory<GiantsquidResponseData> { data in
            do {
                let response = try JSONDecoder().decode(
                    SubqueryResponse<GiantsquidResponseData>.self,
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
        address: String
    ) -> String {
        var filterStrings: [String] = []

        if filters.contains(where: { $0.type == .other && $0.selected }), GiantsquidConfig.giantsquidExtrinsicEnabled {
            filterStrings.append(
                """
                          slashes(where: {accountId_containsInsensitive: \"\(address)\"}) {
                            accountId
                            amount
                            blockNumber
                            era
                            extrinsicHash
                            id
                            timestamp
                          }
                          bonds(where: {accountId_containsInsensitive: \"\(address)\"}) {
                            accountId
                            amount
                            blockNumber
                            extrinsicHash
                            id
                            success
                            timestamp
                            type
                          }
                """
            )
        }

        if filters.contains(where: { $0.type == .reward && $0.selected }), GiantsquidConfig.giantsquidRewardsEnabled {
            filterStrings.append(
                """
                rewards(where: {accountId_containsInsensitive: \"\(address)\"}) {
                accountId
                amount
                blockNumber
                era
                extrinsicHash
                id
                timestamp
                validator
                }
                """
            )
        }

        if filters.contains(where: { $0.type == .transfer && $0.selected }) {
            filterStrings.append(
                """
                          transfers(where: {account: {id_eq: "\(address)"}}, orderBy: id_DESC) {
                           id
                               transfer {
                                 amount
                                 blockNumber
                                 extrinsicHash
                                 from {
                                   id
                                 }
                                 to {
                                   id
                                 }
                                 timestamp
                                 success
                                 id
                               }
                               direction
                          }
                """
            )
        }

        return filterStrings.joined(separator: "\n")
    }

    private func prepareQueryForAddress(
        _ address: String,
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        let filterString = prepareFilter(filters: filters, address: address)
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
        dependingOn remoteOperation: BaseOperation<GiantsquidResponseData>?,
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

            return AssetTransactionPageData(
                transactions: mergeResult.historyItems,
                context: !newHistoryContext.isComplete ? newHistoryContext.toContext() : nil
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

extension GiantsquidHistoryOperationFactory: HistoryOperationFactoryProtocol {
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

        let remoteHistoryOperation: BaseOperation<GiantsquidResponseData>

        if let baseUrl = chain.externalApi?.history?.url {
            remoteHistoryOperation = createOperation(
                address: address,
                url: baseUrl,
                filters: filters
            )
        } else {
            let result = GiantsquidResponseData(transfers: [], stakingRewards: [], bonds: [], slashes: [])
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
            dependingOn: mergeOperation
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
