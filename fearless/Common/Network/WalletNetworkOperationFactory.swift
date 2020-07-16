import Foundation
import CommonWallet
import RobinHood
import xxHash_Swift
import IrohaCrypto
import Starscream

final class WalletNetworkOperationFactory {
    let accountSettings: WalletAccountSettingsProtocol
    let url: URL
    let logger: LoggerProtocol

    init(url: URL, accountSettings: WalletAccountSettingsProtocol, logger: LoggerProtocol) {
        self.url = url
        self.accountSettings = accountSettings
        self.logger = logger
    }
}

extension WalletNetworkOperationFactory: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        guard let asset = assets.first else {
            let operation = BaseOperation<[BalanceData]?>()
            operation.result = .failure(NetworkBaseError.unexpectedEmptyData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        do {
            let accountId = try Data(hexString: self.accountSettings.accountId)

            let key = try StorageKeyFactory().createStorageKey(moduleName: "System",
                                                               serviceName: "Account",
                                                               identifier: accountId).toHex(includePrefix: true)

            let engine = WebSocketEngine(url: url, logger: logger)
            let accountInfoOperation = JSONRPCOperation<JSONScaleDecodable<AccountInfo>>(engine: engine,
                                                                                         method: "state_getStorage",
                                                                                         parameters: [key])
            let mappingOperation = ClosureOperation<[BalanceData]?> {
                guard let accountInfoResult = accountInfoOperation.result else {
                    return nil
                }

                switch accountInfoResult {
                case .success(let info):
                    let amount: AmountDecimal

                    if
                        let accountInfo = info.underlyingValue,
                        let amountDecimal = Decimal.fromKusamaAmount(accountInfo.data.free.value) {
                        amount = AmountDecimal(value: amountDecimal)
                    } else {
                        amount = AmountDecimal(value: 0)
                    }

                    let balance = BalanceData(identifier: asset, balance: amount)

                    return [balance]
                case .failure(let error):
                    throw error
                }
            }

            mappingOperation.addDependency(accountInfoOperation)

            return CompoundOperationWrapper(targetOperation: mappingOperation,
                                            dependencies: [accountInfoOperation])
        } catch {
            let operation = BaseOperation<[BalanceData]?>()
            operation.result = .failure(error)
            return CompoundOperationWrapper(targetOperation: operation)
        }
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
