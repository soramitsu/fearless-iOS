import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt

extension WalletNetworkFacade: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        let userAssets: [WalletAsset] = assets.compactMap { identifier in
            guard identifier != totalPriceAssetId.rawValue else {
                return nil
            }

            return accountSettings.assets.first { $0.identifier == identifier }
        }

        let balanceOperation = fetchBalanceInfoForAsset(userAssets)
        let priceOperations: [CompoundOperationWrapper<Price?>] = userAssets.compactMap {
            if let assetId = WalletAssetId(rawValue: $0.identifier) {
                return fetchPriceOperation(assetId)
            } else {
                return nil
            }
        }

        let currentTotalPriceId = totalPriceAssetId.rawValue

        let mergeOperation: BaseOperation<[BalanceData]?> = ClosureOperation {
            // extract prices

            let prices = priceOperations.compactMap { operation in
                try? operation.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            }

            // match balance with price and form context

            let balances: [BalanceData]? = try balanceOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)?
                .map { balanceData in
                    guard let price = prices
                        .first(where: { $0.assetId.rawValue == balanceData.identifier }) else {
                        return balanceData
                    }

                    let context = BalanceContext(context: balanceData.context ?? [:] )
                        .byChangingPrice(price.lastValue, newPriceChange: price.change)
                        .toContext()

                    return BalanceData(identifier: balanceData.identifier,
                                       balance: balanceData.balance,
                                       context: context)
                }

            // calculate total assets price

            let totalPrice: Decimal = (balances ?? []).reduce(Decimal.zero) { (result, balanceData) in
                let price = BalanceContext(context: balanceData.context ?? [:]).price
                return result + price * balanceData.balance.decimalValue
            }

            // append separate record for total balance and return the list

            let totalPriceBalance = BalanceData(identifier: currentTotalPriceId,
                                                balance: AmountDecimal(value: totalPrice))

            return [totalPriceBalance] + (balances ?? [])
        }

        let flatenedPriceOperations: [Operation] = priceOperations
            .reduce(into: []) { (result, compoundOperation) in
                result.append(contentsOf: compoundOperation.allOperations)
        }

        let dependencies = balanceOperation.allOperations + flatenedPriceOperations

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation,
                                        dependencies: dependencies)
    }

    func fetchTransactionHistoryOperation(_ filter: WalletHistoryRequest, pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?> {

        let historyContext = TransactionHistoryContext(context: pagination.context ?? [:])

        guard !historyContext.isComplete,
            let asset = accountSettings.assets.first(where: { $0.identifier != totalPriceAssetId.rawValue }),
            let assetId = WalletAssetId(rawValue: asset.identifier),
            let url = assetId.subscanUrl?.appendingPathComponent(SubscanApi.history) else {
            let pageData = AssetTransactionPageData(transactions: [],
                                                    context: historyContext.toContext())
            let operation = BaseOperation<AssetTransactionPageData?>()
            operation.result = .success(pageData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let info = HistoryInfo(address: address, row: pagination.count, page: historyContext.page)

        let fetchOperation = subscanOperationFactory.fetchHistoryOperation(url, info: info)

        var dependencies: [Operation] = [fetchOperation]

        let localFetchOperation: BaseOperation<[TransactionHistoryItem]>?

        if info.page == 0 {
            let operation = txStorage.fetchAllOperation(with: RepositoryFetchOptions())
            dependencies.append(operation)

            operation.addDependency(fetchOperation)

            localFetchOperation = operation
        } else {
            localFetchOperation = nil
        }

        let mergeOperation = createHistoryMergeOperation(dependingOn: fetchOperation,
                                                         localOperation: localFetchOperation,
                                                         asset: asset,
                                                         info: info)

        dependencies.forEach { mergeOperation.addDependency($0) }

        dependencies.append(mergeOperation)

        if info.page == 0 {
            let clearOperation = txStorage.saveOperation({ [] }, {
                let mergeResult = try mergeOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                return mergeResult.identifiersToRemove
            })

            dependencies.append(clearOperation)
            clearOperation.addDependency(mergeOperation)
        }

        let mapOperation = createHistoryMapOperation(dependingOn: mergeOperation,
                                                     subscanOperation: fetchOperation,
                                                     info: info)

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: dependencies)
    }

    func transferMetadataOperation(_ info: TransferMetadataInfo)
        -> CompoundOperationWrapper<TransferMetaData?> {
        nodeOperationFactory.transferMetadataOperation(info)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        let currentNetworkType = networkType

        let transferWrapper = nodeOperationFactory.transferOperation(info)

        let saveOperation = txStorage.saveOperation({
            switch transferWrapper.targetOperation.result {
            case .success(let txHash):
                let addressFactory = SS58AddressFactory()
                let item = try TransactionHistoryItem
                    .createFromTransferInfo(info,
                                            transactionHash: txHash,
                                            networkType: currentNetworkType,
                                            addressFactory: addressFactory)
                return [item]
            case .failure(let error):
                throw error
            case .none:
                throw BaseOperationError.parentOperationCancelled
            }
        }, { [] })

        transferWrapper.allOperations.forEach { saveOperation.addDependency($0) }

        let completionOperation: BaseOperation<Data> = ClosureOperation {
            try saveOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try transferWrapper.targetOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }

        let dependencies = [saveOperation] + transferWrapper.allOperations

        completionOperation.addDependency(saveOperation)

        return CompoundOperationWrapper(targetOperation: completionOperation,
                                        dependencies: dependencies)
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        nodeOperationFactory.searchOperation(searchString)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        nodeOperationFactory.contactsOperation()
    }

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo)
        -> CompoundOperationWrapper<WithdrawMetaData?> {
        nodeOperationFactory.withdrawalMetadataOperation(info)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        nodeOperationFactory.withdrawOperation(info)
    }
}
