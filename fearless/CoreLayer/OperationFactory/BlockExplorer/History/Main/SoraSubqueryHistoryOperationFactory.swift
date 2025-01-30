import Foundation
import RobinHood

import IrohaCrypto
import SSFUtils
import SSFModels
import SSFRuntimeCodingService

class SoraSubqueryHistoryOperationFactory {
    private let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    private let chainRegistry: ChainRegistryProtocol

    init(
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.txStorage = txStorage
        self.chainRegistry = chainRegistry
    }

    private func createOperation(
        address: String,
        count: Int,
        cursor: String?,
        url: URL,
        filters: [WalletTransactionHistoryFilter]
    ) -> BaseOperation<SoraSubqueryHistoryData> {
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

        let resultFactory = AnyNetworkResultFactory<SoraSubqueryHistoryData> { data in
            let response = try JSONDecoder().decode(
                GraphQLResponse<SoraSubqueryHistoryData>.self,
                from: data
            )

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response
            }
        }

        let operation = NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )

        return operation
    }

    private func prepareFilter(
        filters: [WalletTransactionHistoryFilter],
        address: String
    ) -> String {
        var filterStrings: [String] = []
        
        var innerFilters: [String] = []
        var outerFilters: [String] = []
        if filters.contains(where: { $0.type == .swap && $0.selected }) {
            innerFilters.append("{module:{equalTo: \"\("liquidityProxy")\"},method:{equalTo: \"\("swap")\"}}")
        }

        if filters.contains(where: { $0.type == .reward && $0.selected }) {
            innerFilters.append("{module:{equalTo: \"\("staking")\"},method:{equalTo: \"\("Rewarded")\"}}")
        }

        if filters.contains(where: { $0.type == .transfer && $0.selected }) {
            innerFilters.append("{module:{equalTo: \"\("assets")\"}, method:{equalTo: \"\("transfer")\"}}")
            outerFilters.append("{module:{equalTo: \"\("assets")\"}, method:{equalTo: \"\("transfer")\"},execution:{contains:{success: true}},data:{contains:{to: \"\(address)\"}}}")
        }
        
        innerFilters.append("{module:{equalTo: \"\("poolXYK")\"},method:{equalTo: \"\("depositLiquidity")\"}},{data:{contains:{method: \"\("depositLiquidity")\"}}}")
        innerFilters.append("{module:{equalTo: \"\("poolXYK")\"},method:{equalTo: \"\("withdrawLiquidity")\"}},{data:{contains:{method: \"\("withdrawLiquidity")\"}}}")
        innerFilters.append("{module:{equalTo: \"\("referrals")\"}}")
        innerFilters.append("{module:{equalTo: \"\("ethBridge")\"},method:{equalTo: \"\("transferToSidechain")\"}}")
        outerFilters.append("{module:{equalTo: \"\("referrals")\"},method:{equalTo: \"\("setReferrer")\"},execution:{contains:{success: true}},data:{contains:{to: \"\(address)\"}}}")
        
        let resultFilters = filterStrings.joined(separator: ",")
        
        let result = "{or:[{address:{equalTo: \"\(address)\"},or:[\(innerFilters.joined(separator: ","))]},\(outerFilters.joined(separator: ","))]}"

        return result
    }

    private func prepareQueryForAddress(
        _ address: String,
        count: Int,
        cursor: String?,
        filters: [WalletTransactionHistoryFilter]
    ) -> String {
        let after = cursor.map { "\"\($0)\"" } ?? "null"
        let filter = prepareFilter(filters: filters, address: address)

        return """
        {
                  historyElements(
                    after: \(after)
                    first: \(count)
                    orderBy: TIMESTAMP_DESC
                    filter: \(filter)
                  ) {
                    pageInfo {
                      startCursor
                      endCursor
                    }
                    nodes {
                      id
                      timestamp
                      address
                      data
                      method
                      module
                      blockHash
                      blockHeight
                      networkFee
                      execution
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
        dependingOn remoteOperation: BaseOperation<SoraSubqueryHistoryData>?,
        runtimeOperation _: BaseOperation<RuntimeCoderFactoryProtocol>,
        localOperation: BaseOperation<[TransactionHistoryItem]>?,
        asset: AssetModel,
        chain: ChainModel,
        address: String
    ) -> BaseOperation<TransactionHistoryMergeResult> {
        ClosureOperation {
            let chainAsset = ChainAsset(chain: chain, asset: asset)
            let remoteTransactions = try remoteOperation?.extractNoCancellableResultData().historyElements.nodes ?? []
            let filteredTransactions = remoteTransactions
                .filter { transaction in
                    if asset.symbol.lowercased() == "val", transaction.method?.lowercased() == "rewarded" {
                        return true
                    }

                    if asset.isUtility, transaction.module?.lowercased() == "staking", transaction.method?.lowercased() != "rewarded" {
                        return true
                    }

                    if let targetAssetId = transaction.data?.targetAssetId, targetAssetId == asset.currencyId {
                        return true
                    }

                    if let baseAssetId = transaction.data?.baseAssetId, baseAssetId == asset.currencyId {
                        return true
                    }

                    if let assetId = transaction.data?.assetId, assetId == asset.currencyId {
                        return true
                    }

                    return false
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
        dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>,
        remoteOperation: BaseOperation<SoraSubqueryHistoryData>
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

extension SoraSubqueryHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return CompoundOperationWrapper.createWithError(RuntimeProviderError.providerUnavailable)
        }
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

        let remoteHistoryOperation: BaseOperation<SoraSubqueryHistoryData>

        if let baseUrl = chain.externalApi?.history?.url {
            remoteHistoryOperation = createOperation(
                address: address,
                count: pagination.count,
                cursor: pagination.context?["endCursor"],
                url: baseUrl,
                filters: filters
            )
        } else {
            let result = SoraSubqueryHistoryData(historyElements: .init(pageInfo: .init(startCursor: nil, endCursor: nil, hasNextPage: nil), nodes: []))
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
}
