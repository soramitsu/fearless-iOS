import Foundation
import BigInt
import CommonWallet
import IrohaCrypto

struct GiantsquidAssetInfo: Decodable {
    let symbol: String
    let amount: String
}

struct GiantsquidDestination: Decodable {
    let id: String
}

struct GiantsquidTransfer: Decodable {
    let id: String
    let asset: GiantsquidAssetInfo
    let to: GiantsquidDestination?
    let from: GiantsquidDestination?
    let success: Bool?
    let extrinsicHash: String?
    let timestamp: String
    let blockNumber: UInt32?
    let type: String?

    var timestampInSeconds: Int64 {
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: Locale.current).date(from: timestamp)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }
}

extension GiantsquidTransfer: WalletRemoteHistoryItemProtocol {
    var identifier: String {
        id
    }

    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { timestampInSeconds }
    var label: WalletRemoteHistorySourceLabel {
        .transfers
    }

    func createTransactionForAddress(
        _ address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            transfer: self,
            address: address,
            chain: chain,
            asset: asset
        )
    }
}
