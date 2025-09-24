import Foundation

import SoraFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: OklinkTransactionItem,
        address: String,
        chain _: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let peerAddress = item.from == address ? item.to : item.from
        let type = item.from == address ? TransactionType.outgoing :
            TransactionType.incoming

        let timestamp: Int64 = {
            let timestamp = Int64(item.transactionTime) ?? 0
            return timestamp / 1000
        }()

        let feeDecimal = Decimal(string: item.txFee, locale: Locale(identifier: "en_EN")) ?? .zero

        let fee = AssetTransactionFee(
            identifier: asset.id,
            assetId: asset.id,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        return AssetTransactionData(
            transactionId: item.txID,
            status: .commited,
            assetId: item.tokenContractAddress,
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(string: item.amount) ?? AmountDecimal(value: 0),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }
}
