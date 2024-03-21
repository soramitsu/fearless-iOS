import Foundation

import SSFModels

struct GiantsquidExtrinsic: Decodable {
    let id: String
    let timestamp: String
    let section: String?
    let method: String?
    let hash: String?
    let status: String?
    let type: String?
    let signedData: GiantsquidSignedData?

    var extrinsicHash: String? {
        hash?.components(separatedBy: "-").first
    }

    var timestampInSeconds: Int64 {
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: Locale.current).date(from: timestamp)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }
}

extension GiantsquidExtrinsic: WalletRemoteHistoryItemProtocol {
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
        chain _: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            extrinsic: self,
            address: address,
            asset: asset
        )
    }
}
