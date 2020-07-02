import Foundation
import CommonWallet
import RobinHood

final class WalletNetworkOperationFactory {}

extension WalletNetworkOperationFactory: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        let operation = ClosureOperation<[BalanceData]?> {
            guard let assetId = assets.first else {
                return nil
            }

            let balance = BalanceData(identifier: assetId, balance: AmountDecimal(value: 0.0))

            return [balance]
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func fetchTransactionHistoryOperation(_ filter: WalletHistoryRequest,
                                          pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?> {
            let operation = ClosureOperation<AssetTransactionPageData?> {
                nil
            }

            return CompoundOperationWrapper(targetOperation: operation)
    }

    func transferMetadataOperation(_ info: TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?> {
        let operation = ClosureOperation<TransferMetaData?> {
            nil
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        let operation = ClosureOperation<Data> {
            Data()
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        let operation = ClosureOperation<[SearchData]?> {
            nil
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        let operation = ClosureOperation<[SearchData]?> {
            nil
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo)
        -> CompoundOperationWrapper<WithdrawMetaData?> {
        let operation = ClosureOperation<WithdrawMetaData?> {
            nil
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        let operation = ClosureOperation<Data> {
            Data()
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
