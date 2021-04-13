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
    case invalidChain
    case invalidReceiver
}

extension WalletNetworkOperationFactory: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        CompoundOperationWrapper<[BalanceData]?>.createWithResult(nil)
    }

    func fetchTransactionHistoryOperation(
        _: WalletHistoryRequest,
        pagination _: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let operation = ClosureOperation<AssetTransactionPageData?> {
            nil
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func transferMetadataOperation(
        _ info: TransferMetadataInfo
    ) -> CompoundOperationWrapper<TransferMetaData?> {
        guard let asset = accountSettings.assets.first(where: { $0.identifier == info.assetId }) else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let amount = Decimal(1.0).toSubstrateAmount(precision: asset.precision) else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let receiver = try? Data(hexString: info.receiver) else {
            let error = WalletNetworkOperationFactoryError.invalidReceiver
            return CompoundOperationWrapper.createWithError(error)
        }

        let compoundReceiver = createAccountInfoFetchOperation(receiver)

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let args = TransferCall(dest: .accoundId(receiver), value: amount)
            let call = RuntimeCall<TransferCall>.transfer(args)
            return try builder.adding(call: call)
        }

        let infoWrapper = extrinsicFactory.estimateFeeOperation(builderClosure)

        let mapOperation: ClosureOperation<TransferMetaData?> = ClosureOperation {
            let paymentInfo = try infoWrapper.targetOperation.extractNoCancellableResultData()

            guard let fee = BigUInt(paymentInfo.fee),
                  let decimalFee = Decimal.fromSubstrateAmount(fee, precision: asset.precision)
            else {
                return nil
            }

            let amount = AmountDecimal(value: decimalFee)

            let feeDescription = FeeDescription(
                identifier: asset.identifier,
                assetId: asset.identifier,
                type: FeeType.fixed.rawValue,
                parameters: [amount]
            )

            if let receiverInfo = try compoundReceiver.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) {
                let context = TransferMetadataContext(
                    data: receiverInfo.data,
                    precision: asset.precision
                ).toContext()
                return TransferMetaData(feeDescriptions: [feeDescription], context: context)
            } else {
                return TransferMetaData(feeDescriptions: [feeDescription])
            }
        }

        let dependencies = compoundReceiver.allOperations + infoWrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        guard let asset = accountSettings.assets.first(where: { $0.identifier == info.asset }) else {
            let error = WalletNetworkOperationFactoryError.invalidAsset
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let amount = info.amount.decimalValue.toSubstrateAmount(precision: asset.precision) else {
            let error = WalletNetworkOperationFactoryError.invalidAmount
            return CompoundOperationWrapper.createWithError(error)
        }

        guard let receiver = try? Data(hexString: info.destination) else {
            let error = WalletNetworkOperationFactoryError.invalidReceiver
            return CompoundOperationWrapper.createWithError(error)
        }

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            let args = TransferCall(dest: .accoundId(receiver), value: amount)
            let call = RuntimeCall<TransferCall>.transfer(args)
            return try builder.adding(call: call)
        }

        let wrapper = extrinsicFactory.submit(builderClosure, signer: accountSigner)

        let mapOperation: ClosureOperation<Data> = ClosureOperation {
            let hashString = try wrapper.targetOperation.extractNoCancellableResultData()
            return try Data(hexString: hashString)
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }

    func searchOperation(_: String) -> CompoundOperationWrapper<[SearchData]?> {
        CompoundOperationWrapper<[SearchData]?>.createWithResult(nil)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        CompoundOperationWrapper<[SearchData]?>.createWithResult(nil)
    }

    func withdrawalMetadataOperation(
        _: WithdrawMetadataInfo
    ) -> CompoundOperationWrapper<WithdrawMetaData?> {
        CompoundOperationWrapper<WithdrawMetaData?>.createWithResult(nil)
    }

    func withdrawOperation(_: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        CompoundOperationWrapper<Data>.createWithResult(Data())
    }
}
