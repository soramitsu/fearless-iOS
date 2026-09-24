import Foundation
import SoraFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: KaiaHistoryTransaction,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) throws -> AssetTransactionData {
        guard let timestamp = item.timestampInSeconds else {
            throw KaiaHistoryError.providerRejected
        }
        let isOutgoing = item.fromAddress.caseInsensitiveCompare(address) == .orderedSame
        let peerAddress = isOutgoing ? item.toAddress : item.fromAddress
        let type = isOutgoing ? TransactionType.outgoing :
            TransactionType.incoming

        let fees: [AssetTransactionFee]
        if let transactionFee = item.transactionFee {
            let utilityAsset = chain.utilityChainAssets().first?.asset ?? asset
            fees = [AssetTransactionFee(
                identifier: utilityAsset.id,
                assetId: utilityAsset.id,
                amount: AmountDecimal(value: transactionFee),
                context: nil
            )]
        } else {
            // KaiaScan token-transfer rows do not contain the network fee.
            fees = []
        }

        return AssetTransactionData(
            transactionId: item.transactionHash,
            status: item.status?.status == "Fail" ? .rejected : .commited,
            assetId: item.contract?.contractAddress ?? asset.id,
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: item.amount),
            fees: fees,
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }
}
