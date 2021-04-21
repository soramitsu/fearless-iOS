import Foundation
import IrohaCrypto
import FearlessUtils

extension TransactionHistoryItem {
    static func createFromSubscriptionResult(
        _ result: TransferSubscriptionResult,
        fee: Decimal,
        address: String,
        addressFactory: SS58AddressFactoryProtocol
    ) -> TransactionHistoryItem? {
        do {
            let typeRawValue = try addressFactory.type(fromAddress: address)

            guard let addressType = SNAddressType(rawValue: typeRawValue.uint8Value) else {
                return nil
            }

            guard let txOrigin = try? result.extrinsic.signature?
                .address.map(to: MultiAddress.self).accountId else {
                return nil
            }

            guard let txReceiver = result.call.dest.accountId else {
                return nil
            }

            let sender = try addressFactory.addressFromAccountId(data: txOrigin, type: addressType)
            let receiver = try addressFactory.addressFromAccountId(data: txReceiver, type: addressType)

            let timestamp = Int64(Date().timeIntervalSince1970)

            let callArgs = try JSONEncoder.scaleCompatible().encode(result.call)
            let callPath = CallCodingPath.transfer

            return TransactionHistoryItem(
                sender: sender,
                receiver: receiver,
                status: .success,
                txHash: result.extrinsicHash.toHex(includePrefix: true),
                timestamp: timestamp,
                fee: fee.stringWithPointSeparator,
                blockNumber: result.blockNumber,
                txIndex: result.txIndex,
                callName: callPath.callName,
                moduleName: callPath.moduleName,
                callArgs: callArgs
            )

        } catch {
            return nil
        }
    }
}
