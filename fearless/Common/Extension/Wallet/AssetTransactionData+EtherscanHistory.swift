import Foundation
import CommonWallet
import SoraFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: EtherscanHistoryElement,
        address: String,
        chain _: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let peerAddress = item.from == address ? item.to : item.from
        let type = item.from == address ? TransactionType.outgoing :
            TransactionType.incoming

        let timestamp: Int64 = {
            let timestamp = Int64(item.timeStamp) ?? 0
            return timestamp
        }()

        let amount = Decimal.fromSubstrateAmount(item.value, precision: Int16(asset.precision)) ?? .zero

        return AssetTransactionData(
            transactionId: item.hash,
            status: .commited,
            assetId: item.contractAddress,
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }
}
