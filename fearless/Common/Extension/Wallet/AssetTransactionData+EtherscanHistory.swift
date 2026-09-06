import Foundation
import SoraFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: EtherscanHistoryElement,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let peerAddress = item.from?.lowercased() == address.lowercased() ? item.to : item.from
        let type = item.from?.lowercased() == address.lowercased() ? TransactionType.outgoing :
            TransactionType.incoming

        let timestamp: Int64 = {
            guard let timestampValue = item.timeStamp else {
                return 0
            }

            let timestamp = Int64(timestampValue) ?? 0
            return timestamp
        }()

        let feeValue = item.gasUsed * item.gasPrice

        let utilityAsset = chain.utilityChainAssets().first?.asset ?? asset
        let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: Int16(utilityAsset.precision)) ?? .zero

        let fee = AssetTransactionFee(
            identifier: utilityAsset.id,
            assetId: utilityAsset.id,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )
        let amount = Decimal.fromSubstrateAmount(item.value, precision: Int16(asset.precision)) ?? .zero

        return AssetTransactionData(
            transactionId: item.hash ?? "",
            status: item.isError == "1" ? .rejected : .commited,
            assetId: asset.id,
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
