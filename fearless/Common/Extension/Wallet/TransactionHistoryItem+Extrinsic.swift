import Foundation
import IrohaCrypto
import FearlessUtils

extension TransactionHistoryItem {
    static func createFromExtrinsic(_ extrinsic: Extrinsic,
                                    fee: Decimal,
                                    address: String,
                                    txHash: Data,
                                    blockNumber: UInt32,
                                    txIndex: Int16,
                                    addressFactory: SS58AddressFactoryProtocol) -> TransactionHistoryItem? {
        do {
            let typeRawValue = try addressFactory.type(fromAddress: address)

            guard let addressType = SNAddressType(rawValue: typeRawValue.uint8Value) else {
                return nil
            }

            guard let txOrigin = extrinsic.transaction?.accountId else {
                return nil
            }

            guard extrinsic.call.moduleIndex == ExtrinsicConstants.balanceModuleIndex else {
                return nil
            }

            let isValidCallIndex = [
                ExtrinsicConstants.transferCallIndex,
                ExtrinsicConstants.keepAliveTransferIndex
            ].contains(extrinsic.call.callIndex)

            guard isValidCallIndex else {
                return nil
            }

            guard let argData = extrinsic.call.arguments else {
                return nil
            }

            let transferData = try TransferCall(scaleDecoder: ScaleDecoder(data: argData))

            let sender = try addressFactory.address(fromPublicKey: AccountIdWrapper(rawData: txOrigin),
                                                    type: addressType)
            let receiver = try addressFactory
                .address(fromPublicKey: AccountIdWrapper(rawData: transferData.receiver),
                         type: addressType)

            let timestamp = Int64(Date().timeIntervalSince1970)
            let amount = Decimal.fromSubstrateAmount(transferData.amount,
                                                     precision: addressType.precision) ?? .zero

            return TransactionHistoryItem(sender: sender,
                                          receiver: receiver,
                                          status: .success,
                                          txHash: txHash.toHex(includePrefix: true),
                                          timestamp: timestamp,
                                          amount: amount.stringWithPointSeparator,
                                          fee: fee.stringWithPointSeparator,
                                          blockNumber: Int64(blockNumber),
                                          txIndex: txIndex)

        } catch {
            return nil
        }
    }
}
