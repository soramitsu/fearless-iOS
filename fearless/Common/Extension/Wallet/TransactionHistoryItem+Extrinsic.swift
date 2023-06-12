import Foundation
import IrohaCrypto
import SSFUtils
import Web3
import SSFModels

extension TransactionHistoryItem {
    static func createFromSubscriptionResult(
        _ result: TransactionSubscriptionResult,
        address: String,
        chain: ChainModel
    ) -> TransactionHistoryItem? {
        do {
            let extrinsic = result.processingResult.extrinsic

            guard let txOrigin = try? extrinsic.signature?.address.map(to: MultiAddress.self).accountId else {
                return nil
            }

            let sender = try AddressFactory.address(for: txOrigin, chain: chain)
            let receiver: AccountAddress? = {
                if sender != address {
                    return address
                } else {
                    if let peerId = result.processingResult.peerId {
                        return try? AddressFactory.address(for: peerId, chain: chain)
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
