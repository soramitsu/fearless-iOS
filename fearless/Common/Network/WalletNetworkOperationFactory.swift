import Foundation
import CommonWallet
import RobinHood
import xxHash_Swift
import IrohaCrypto
import Starscream

final class WalletNetworkOperationFactory {
    let accountSettings: WalletAccountSettingsProtocol
    let url: URL

    init(url: URL, accountSettings: WalletAccountSettingsProtocol) {
        self.url = url
        self.accountSettings = accountSettings
    }
}

extension WalletNetworkOperationFactory: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        guard let asset = assets.first else {
            let operation = BaseOperation<[BalanceData]?>()
            operation.result = .failure(NetworkBaseError.unexpectedEmptyData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let operation = ClosureOperation<[BalanceData]?> {
            guard let moduleKey = "System".data(using: .utf8) else {
                throw NetworkBaseError.badSerialization
            }

            guard let serviceKey = "Account".data(using: .utf8) else {
                throw NetworkBaseError.badSerialization
            }

            let accountId = try Data(hexString: self.accountSettings.accountId)

            let moduleKeyHash = moduleKey.xxh128()
            let serviceKeyHash = serviceKey.xxh128()

            let accountIdKey = try (accountId as NSData).blake2b(16)

            let key = (moduleKeyHash + serviceKeyHash + accountIdKey + accountId).toHex(includePrefix: true)

            let info = JSONRPCInfo(identifier: 1,
                                   jsonrpc: "2.0",
                                   method: "state_getStorage",
                                   params: [key])

            let request = URLRequest(url: self.url)

            let webSocket = WebSocket(request: request)

            let semaphone = DispatchSemaphore(value: 0)

            let requestData = try JSONEncoder().encode(info)

            var responseData: Data?
            var websocketError: Error?

            webSocket.onEvent = { event in
                switch event {
                case .connected:
                    webSocket.write(data: requestData, completion: nil)
                case .disconnected:
                    websocketError = BaseOperationError.unexpectedDependentResult
                    semaphone.signal()
                case .text(let string):
                    responseData = string.data(using: .utf8)
                    semaphone.signal()
                case .binary(let data):
                    responseData = data
                    semaphone.signal()
                case .ping:
                    break
                case .pong:
                    break
                case .viabilityChanged:
                    break
                case .reconnectSuggested:
                    break
                case .cancelled:
                    semaphone.signal()
                case .error(let error):
                    websocketError = error
                    semaphone.signal()
                }
            }

            webSocket.connect()

            semaphone.wait()

            webSocket.disconnect()

            if let data = responseData {
                let response = try JSONDecoder().decode(JSONRPCData.self, from: data)

                let amount: AmountDecimal

                if let result = response.result {
                    let resultData = try Data(hexString: result)
                    let scaleDecoder = try ScaleDecoder(data: resultData)
                    let accountInfo = try AccountInfo(scaleDecoder: scaleDecoder)

                    if let amountDecimal = Decimal.fromKusamaAmount(accountInfo.data.free.value) {
                        amount = AmountDecimal(value: amountDecimal)
                    } else {
                        amount = AmountDecimal(value: 0)
                    }

                } else {
                    amount = AmountDecimal(value: 0)
                }

                Logger.shared.debug("amount \(amount)")

                let balance = BalanceData(identifier: asset, balance: amount)
                return [balance]
            } else if let error = websocketError {
                throw error
            }

            throw BaseOperationError.parentOperationCancelled
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
