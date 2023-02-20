import Foundation
import BigInt
import CommonWallet
import IrohaCrypto

struct GiantsquidReward: Decodable {
    let amount: String
    let era: UInt32?
    let accountId: String?
    let validator: String?
    let timestamp: String
    let extrinsicHash: String?
    let blockNumber: UInt32?
    let id: String

    var timestampInSeconds: Int64 {
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: Locale.current).date(from: timestamp)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }
}

extension GiantsquidReward: WalletRemoteHistoryItemProtocol {
    var identifier: String {
        id
    }

    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { timestampInSeconds }
    var label: WalletRemoteHistorySourceLabel {
        .rewards
    }

    func createTransactionForAddress(
        _ address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            reward: self,
            address: address,
            chain: chain,
            asset: asset
        )
    }
}
