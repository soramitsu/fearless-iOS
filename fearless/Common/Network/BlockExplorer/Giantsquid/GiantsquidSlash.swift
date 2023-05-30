import Foundation
import CommonWallet
import SSFModels

struct GiantsquidSlash: Decodable {
    let id: String
    let accountId: String
    let amount: String
    let blockNumber: UInt32
    let era: UInt32
    let timestamp: String

    var timestampInSeconds: Int64 {
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: Locale.current).date(from: timestamp)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }
}

extension GiantsquidSlash: WalletRemoteHistoryItemProtocol {
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
            slash: self,
            address: address,
            chain: chain,
            asset: asset
        )
    }
}
