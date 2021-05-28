import Foundation
import IrohaCrypto
import FearlessUtils
import BigInt

extension TransactionHistoryItem {
    static func createFromSubscriptionResult(
        _ result: TransactionSubscriptionResult,
        address: String,
        addressFactory: SS58AddressFactoryProtocol
    ) -> TransactionHistoryItem? {
        do {
            let typeRawValue = try addressFactory.type(fromAddress: address)
            let extrinsic = result.processingResult.extrinsic

            guard let addressType = SNAddressType(rawValue: typeRawValue.uint8Value) else {
                return nil
            }

            guard let txOrigin = try? extrinsic.signature?.address.map(to: MultiAddress.self).accountId else {
                return nil
            }

            let sender = try addressFactory.addressFromAccountId(data: txOrigin, type: addressType)
            let receiver: AccountAddress? = {
                if sender != address {
                    return address
                } else {
                    if let peerId = result.processingResult.peerId {
                        return try? addressFactory.addressFromAccountId(data: peerId, type: addressType)
                    } else {
                        return nil
                    }
                }
            }()

            let timestamp = Int64(Date().timeIntervalSince1970)

            let encodedCall = try JSONEncoder.scaleCompatible().encode(extrinsic.call)

            return TransactionHistoryItem(
                sender: sender,
                receiver: receiver,
                status: result.processingResult.isSuccess ? .success : .failed,
                txHash: result.extrinsicHash.toHex(includePrefix: true),
                timestamp: timestamp,
                fee: String(result.processingResult.fee ?? 0),
                blockNumber: result.blockNumber,
                txIndex: result.txIndex,
                callPath: result.processingResult.callPath,
                call: encodedCall
            )

        } catch {
            return nil
        }
    }
}
