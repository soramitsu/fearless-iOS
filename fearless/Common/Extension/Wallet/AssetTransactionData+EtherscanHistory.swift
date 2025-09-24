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
        let peerAddress = item.from == address ? item.to : item.from
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
            identifier: asset.id,
            assetId: asset.id,
            amount: AmountDecimal(value: feeDecimal),
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
