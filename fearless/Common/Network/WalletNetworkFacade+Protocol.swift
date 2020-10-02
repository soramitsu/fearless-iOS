import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt

extension WalletNetworkFacade: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        let assetIds: [WalletAssetId] = assets.compactMap { identifier in
            if
                identifier != totalPriceAssetId.rawValue,
                let assetId = WalletAssetId(rawValue: identifier) {
                return assetId
            } else {
                return nil
            }
        }

        let balanceOperation = nodeOperationFactory.fetchBalanceOperation(assetIds.map { $0.rawValue })
        let priceOperations = assetIds.map { fetchPriceOperation($0) }

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

                    let context = BalanceContext(price: price.lastValue,
                                                 priceChange: price.change).toContext()

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

    func fetchTransactionHistoryOperation(_ filter: WalletHistoryRequest,
                                          pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?> {

        let historyContext = TransactionHistoryContext(context: pagination.context ?? [:])

            guard !historyContext.isComplete,
                let asset = accountSettings.assets
                    .first(where: { $0.identifier != totalPriceAssetId.rawValue }),
                let assetId = WalletAssetId(rawValue: asset.identifier),
                let url = assetId.subscanUrl?.appendingPathComponent(SubscanApi.history) else {
            let pageData = AssetTransactionPageData(transactions: [],
                                                    context: historyContext.toContext())
            let operation = BaseOperation<AssetTransactionPageData?>()
            operation.result = .success(pageData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let currentNetworkType = networkType

        let info = HistoryInfo(address: address,
                               row: pagination.count,
                               page: historyContext.page)

        let fetchOperation = subscanOperationFactory.fetchHistoryOperation(url, info: info)

        let addressFactory = SS58AddressFactory()

        let mapOperation: BaseOperation<AssetTransactionPageData?> = ClosureOperation {
            let pageData = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let isComplete = pageData.count < pagination.count
            let newHistoryContext = TransactionHistoryContext(page: info.page + 1,
                                                              isComplete: isComplete)

            let transactions: [AssetTransactionData] = (pageData.transactions ?? []).map { item in
                let status: AssetTransactionStatus

                if let state = item.success {
                    status = state ? .commited : .rejected
                } else {
                    status = .pending
                }

                let peerAddress = item.sender == info.address ? item.receiver : item.sender

                let accountId = try? addressFactory.accountId(fromAddress: peerAddress,
                                                              type: currentNetworkType)

                let peerId = accountId?.toHex() ?? peerAddress

                let amount = AmountDecimal(string: item.amount) ?? AmountDecimal(value: 0)
                let feeValue = BigUInt(item.fee) ?? BigUInt(0)
                let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero

                let fee = AssetTransactionFee(identifier: assetId.rawValue,
                                              assetId: assetId.rawValue,
                                              amount: AmountDecimal(value: feeDecimal),
                                              context: nil)

                let type = item.sender == info.address ? TransactionType.outgoing :
                    TransactionType.incoming

                return AssetTransactionData(transactionId: item.hash,
                                            status: status,
                                            assetId: assetId.rawValue,
                                            peerId: peerId,
                                            peerFirstName: nil,
                                            peerLastName: nil,
                                            peerName: peerAddress,
                                            details: "",
                                            amount: amount,
                                            fees: [fee],
                                            timestamp: item.timestamp,
                                            type: type.rawValue,
                                            reason: nil,
                                            context: nil)
            }

            return AssetTransactionPageData(transactions: transactions,
                                            context: newHistoryContext.toContext())
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: [fetchOperation])
    }

    func transferMetadataOperation(_ info: TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?> {
        nodeOperationFactory.transferMetadataOperation(info)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        nodeOperationFactory.transferOperation(info)
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        nodeOperationFactory.searchOperation(searchString)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        nodeOperationFactory.contactsOperation()
    }

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo) -> CompoundOperationWrapper<WithdrawMetaData?> {
        nodeOperationFactory.withdrawalMetadataOperation(info)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        nodeOperationFactory.withdrawOperation(info)
    }
}
