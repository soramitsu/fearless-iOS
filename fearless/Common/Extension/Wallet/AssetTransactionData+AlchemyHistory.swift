import Foundation
import CommonWallet
import SoraFoundation

extension AssetTransactionData {
    static func createTransaction(
        from item: AlchemyHistoryElement,
        address: String,
        chain _: ChainModel,
        asset _: AssetModel
    ) -> AssetTransactionData {
        let peerAddress = item.from == address ? item.to : item.from
        let type = item.from == address ? TransactionType.outgoing :
            TransactionType.incoming

        let timestamp: Int64 = {
            guard let metadata = item.metadata else {
                return 0
            }

            let locale = LocalizationManager.shared.selectedLocale
            let dateFormatter = DateFormatter.giantsquidDate
            let date = dateFormatter.value(for: locale).date(from: metadata.blockTimestamp)
            let timestamp = Int64(date?.timeIntervalSince1970 ?? 0)
            return timestamp
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
