import Foundation
import SoraFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: ViscanHistoryElement,
        address: String,
        chain _: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let peerAddress = item.from?.lowercased() == address.lowercased() ? item.to : item.from
        let type = item.from?.lowercased() == address.lowercased() ? TransactionType.outgoing :
            TransactionType.incoming

        let timestamp: Int64 = {
            guard let timestampValue = item.timestamp else {
                return 0
            }

            let timestamp = Int64(timestampValue)
            return timestamp
        }()

        let fee = AssetTransactionFee(
            identifier: asset.id,
            assetId: asset.id,
            amount: AmountDecimal(value: item.fee),
            context: nil
        )
        let amount = Decimal.fromSubstrateAmount(item.value, precision: Int16(asset.precision)) ?? .zero

        return AssetTransactionData(
            transactionId: item.hash ?? "",
            status: .commited,
            assetId: item.contractAddress ?? "",
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }
}
