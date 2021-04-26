import Foundation
import CommonWallet
import IrohaCrypto
import BigInt
import FearlessUtils

extension TransactionHistoryItem {
    static func createFromTransferInfo(
        _ info: TransferInfo,
        transactionHash: Data,
        networkType: SNAddressType,
        addressFactory: SS58AddressFactoryProtocol
    ) throws
        -> TransactionHistoryItem {
        let senderAccountId = try Data(hexString: info.source)
        let receiverAccountId = try Data(hexString: info.destination)

        let sender = try addressFactory.address(
            fromPublicKey: AccountIdWrapper(rawData: senderAccountId),
            type: networkType
        )

        let receiver = try addressFactory.address(
            fromPublicKey: AccountIdWrapper(rawData: receiverAccountId),
            type: networkType
        )

        guard let amount = info.amount.decimalValue
            .toSubstrateAmount(precision: networkType.precision) else {
            throw AmountDecimalError.invalidStringValue
        }

        let callPath = CallCodingPath.transfer
        let callArgs = TransferCall(dest: .accoundId(receiverAccountId), value: amount)
        let call = RuntimeCall<TransferCall>(
            moduleName: callPath.moduleName,
            callName: callPath.callName,
            args: callArgs
        )
        let encodedCall = try JSONEncoder.scaleCompatible().encode(call)

        let totalFee = info.fees.reduce(Decimal(0)) { total, fee in total + fee.value.decimalValue }

        guard let feeValue = totalFee.toSubstrateAmount(precision: networkType.precision) else {
            throw AmountDecimalError.invalidStringValue
        }

        let timestamp = Int64(Date().timeIntervalSince1970)

        return TransactionHistoryItem(
            sender: sender,
            receiver: receiver,
            status: .pending,
            txHash: transactionHash.toHex(includePrefix: true),
            timestamp: timestamp,
            fee: String(feeValue),
            blockNumber: nil,
            txIndex: nil,
            callPath: callPath,
            call: encodedCall
        )
    }
}

extension TransactionHistoryItem.Status {
    var walletValue: AssetTransactionStatus {
        switch self {
        case .success:
            return .commited
        case .failed:
            return .rejected
        case .pending:
            return .pending
        }
    }
}
