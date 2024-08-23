import Foundation
import SoraFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: KaiaHistoryTransaction,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let peerAddress = item.fromAddress?.lowercased() == address.lowercased() ? item.toAddress : item.fromAddress
        let type = item.fromAddress?.lowercased() == address.lowercased() ? TransactionType.outgoing :
            TransactionType.incoming

        let utilityAsset = chain.utilityChainAssets().first?.asset ?? asset
        let feeDecimal = Decimal.fromSubstrateAmount(item.txFee, precision: Int16(utilityAsset.precision)) ?? .zero

        let fee = AssetTransactionFee(
            identifier: asset.id,
            assetId: asset.id,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )
        let amount = Decimal.fromSubstrateAmount(item.amount, precision: Int16(asset.precision)) ?? .zero

        return AssetTransactionData(
            transactionId: item.txHash ?? "",
            status: .commited,
            assetId: "",
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [fee],
            timestamp: item.timestampInSeconds,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }
}
