import Foundation
import IrohaCrypto
import FearlessUtils

extension TransactionHistoryItem {
    static func createFromSubscriptionResult(_ result: TransferSubscriptionResult,
                                             fee: Decimal,
                                             address: String,
                                             addressFactory: SS58AddressFactoryProtocol)
        -> TransactionHistoryItem? {
        do {
            let typeRawValue = try addressFactory.type(fromAddress: address)

            guard let addressType = SNAddressType(rawValue: typeRawValue.uint8Value) else {
                return nil
            }

            guard let txOrigin = result.extrinsic.transaction?.accountId else {
                return nil
            }

            let sender = try addressFactory.address(fromPublicKey: AccountIdWrapper(rawData: txOrigin),
                                                    type: addressType)
            let receiver = try addressFactory
                .address(fromPublicKey: AccountIdWrapper(rawData: result.call.receiver),
                         type: addressType)

            let timestamp = Int64(Date().timeIntervalSince1970)
            let amount = Decimal.fromSubstrateAmount(result.call.amount,
                                                     precision: addressType.precision) ?? .zero

            return TransactionHistoryItem(sender: sender,
                                          receiver: receiver,
                                          status: .success,
                                          txHash: result.extrinsicHash.toHex(includePrefix: true),
                                          timestamp: timestamp,
                                          amount: amount.stringWithPointSeparator,
                                          fee: fee.stringWithPointSeparator,
                                          blockNumber: result.blockNumber,
                                          txIndex: result.txIndex)

        } catch {
            return nil
        }
    }
}
