import Foundation
import CommonWallet
import SoraFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: ZetaItem,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let peerAddress = item.from.hash == address ? item.to.hash : item.from.hash
        let type = item.from.hash == address ? TransactionType.outgoing : TransactionType.incoming

        let timestamp: Int64 = {
            let locale = LocalizationManager.shared.selectedLocale
            let dateFormatter = DateFormatter.giantsquidDate
            let date = dateFormatter.value(for: locale).date(from: item.timestamp)
            let timestamp = Int64(date?.timeIntervalSince1970 ?? 0)
            return timestamp
        }()

        let feeValue = item.fee?.value ?? .zero

        let utilityAsset = chain.utilityChainAssets().first?.asset ?? asset
        let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: Int16(utilityAsset.precision)) ?? .zero

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let amountValue = item.value ?? item.total?.value ?? .zero
        let amount = Decimal.fromSubstrateAmount(amountValue, precision: Int16(asset.precision)) ?? .zero

        return AssetTransactionData(
            transactionId: item.hash ?? item.txHash ?? "",
            status: .commited,
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
