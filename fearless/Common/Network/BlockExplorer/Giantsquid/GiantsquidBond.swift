import Foundation
import CommonWallet

struct GiantsquidBond: Decodable {
    let id: String
    let accountId: String
    let amount: String
    let blockNumber: UInt32
    let extrinsicHash: String?
    let success: Bool?
    let timestamp: String
    let type: String?

    var timestampInSeconds: Int64 {
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: Locale.current).date(from: timestamp)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }
}

extension GiantsquidBond: WalletRemoteHistoryItemProtocol {
    var identifier: String {
        id
    }

    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { timestampInSeconds }
    var label: WalletRemoteHistorySourceLabel {
        .extrinsics
    }

    func createTransactionForAddress(
        _ address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            bond: self,
            address: address,
            chain: chain,
            asset: asset
        )
    }
}
