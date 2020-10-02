import Foundation
import CommonWallet
import RobinHood
import xxHash_Swift
import FearlessUtils
import IrohaCrypto
import Starscream
import BigInt

enum WalletNetworkOperationFactoryError: Error {
    case invalidAmount
    case invalidAsset
}

extension WalletNetworkOperationFactory: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        guard
            let assetId = assets.first,
            let asset = accountSettings.assets.first(where: { $0.identifier == assetId }) else {
            let operation = BaseOperation<[BalanceData]?>()
            operation.result = .failure(NetworkBaseError.unexpectedEmptyData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let accountInfoOperation = createAccountInfoFetchOperation()

        let mappingOperation = ClosureOperation<[BalanceData]?> {
            guard let accountInfoResult = accountInfoOperation.result else {
                return nil
            }

            switch accountInfoResult {
            case .success(let info):
                let amount: AmountDecimal

                if
                    let accountInfo = info.underlyingValue,
                    let amountDecimal = Decimal
                        .fromSubstrateAmount(accountInfo.data.free.value, precision: asset.precision) {
                    amount = AmountDecimal(value: amountDecimal)
                } else {
                    amount = AmountDecimal(value: 0)
                }

                let balance = BalanceData(identifier: asset.identifier, balance: amount)

                return [balance]
            case .failure(let error):
                throw error
            }
        }

        mappingOperation.addDependency(accountInfoOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation,
                                        dependencies: [accountInfoOperation])
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
        guard let asset = accountSettings.assets.first(where: { $0.identifier == info.assetId }) else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return createCompoundOperation(result: .failure(error))
        }

        guard let amount = Decimal(1.0).toSubstrateAmount(precision: asset.precision) else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return createCompoundOperation(result: .failure(error))
        }

        let engine = WebSocketEngine(url: url, logger: logger)

        let infoOperation = JSONRPCOperation<RuntimeDispatchInfo>(engine: engine,
                                                                  method: RPCMethod.paymentInfo)

        let compoundInfo = setupTransferExtrinsic(infoOperation,
                                                  amount: amount,
                                                  sender: info.sender,
                                                  receiver: info.receiver,
                                                  signer: dummySigner)

        let mapOperation: ClosureOperation<TransferMetaData?> = ClosureOperation {
            let paymentInfo = try infoOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let fee = BigUInt(paymentInfo.fee),
                let decimalFee = Decimal.fromSubstrateAmount(fee, precision: asset.precision) else {
                return nil
            }

            let amount = AmountDecimal(value: decimalFee)

            let feeDescription = FeeDescription(identifier: asset.identifier,
                                                assetId: asset.identifier,
                                                type: FeeType.fixed.rawValue,
                                                parameters: [amount])

            return TransferMetaData(feeDescriptions: [feeDescription])
        }

        mapOperation.addDependency(compoundInfo.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: compoundInfo.allOperations)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        guard let asset = accountSettings.assets.first(where: { $0.identifier == info.asset }) else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return createCompoundOperation(result: .failure(error))
        }

        guard let amount = info.amount.decimalValue.toSubstrateAmount(precision: asset.precision) else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return createCompoundOperation(result: .failure(error))
        }

        let engine = WebSocketEngine(url: url, logger: logger)

        let transferOperation = JSONRPCOperation<String>(engine: engine,
                                                         method: RPCMethod.submitExtrinsic)

        let compoundTransfer = setupTransferExtrinsic(transferOperation,
                                                      amount: amount,
                                                      sender: info.source,
                                                      receiver: info.destination,
                                                      signer: accountSigner)

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try transferOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return try Data(hexString: hashString)
        }

        mapOperation.addDependency(compoundTransfer.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation,
                                        dependencies: compoundTransfer.allOperations)
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
