import Foundation
import BigInt
import CommonWallet
import IrohaCrypto
import SoraFoundation
import SSFModels

struct ReefDestination: Decodable {
    let id: String
}

// struct ReefTransfer: Decodable {
//    let id: String
//    let amount: String
//    let to: ReefDestination?
//    let from: ReefDestination?
//    let success: Bool?
//    let extrinsicHash: String?
//    let timestamp: String
//    let blockNumber: UInt32?
//    let type: String?
//
//    var timestampInSeconds: Int64 {
//        let locale = LocalizationManager.shared.selectedLocale
//        let dateFormatter = DateFormatter.giantsquidDate
//        let date = dateFormatter.value(for: locale).date(from: timestamp)
//        return Int64(date?.timeIntervalSince1970 ?? 0)
//    }
// }
//
// extension ReefTransfer: WalletRemoteHistoryItemProtocol {
//    var identifier: String {
//        id
//    }
//
//    var itemBlockNumber: UInt64 { 0 }
//    var itemExtrinsicIndex: UInt16 { 0 }
//    var itemTimestamp: Int64 { timestampInSeconds }
//    var label: WalletRemoteHistorySourceLabel {
//        .transfers
//    }
//
//    func createTransactionForAddress(
//        _ address: String,
//        chain _: ChainModel,
//        asset: AssetModel
//    ) -> AssetTransactionData {
//        AssetTransactionData.createTransaction(
//            transfer: self,
//            address: address,
//            asset: asset
//        )
//    }
// }

struct ReefResponse: Decodable {
    let data: GiantsquidResponseData
}

struct ReefResponseData: Decodable {
    let transfers: [GiantsquidTransfer]?

    var history: [WalletRemoteHistoryItemProtocol] {
        transfers ?? []
    }
}

extension ReefResponseData: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        []
    }
}
