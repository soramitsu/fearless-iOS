import Foundation

import FearlessFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: AlchemyHistoryElement,
        address: String
    ) -> AssetTransactionData {
        let peerAddress = item.from == address ? item.to : item.from
        let type = item.from == address ? TransactionType.outgoing :
            TransactionType.incoming

        let timestamp: Int64 = {
            guard let metadata = item.metadata else {
                return 0
            }

            return DateFormatter.networkTimestampInSeconds(
                from: metadata.blockTimestamp,
                using: DateFormatter.alchemyDate
            )
        }()

        return AssetTransactionData(
            transactionId: item.uniqueId,
            status: .commited,
            assetId: item.asset,
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: item.value),
            fees: [],
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }
}
