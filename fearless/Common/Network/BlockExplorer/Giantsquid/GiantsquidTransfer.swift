import Foundation
import BigInt

import IrohaCrypto
import SoraFoundation
import SSFModels
import SSFUtils

struct GiantsquidDestination: Decodable {
    let id: String
}

struct GiantsquidTransferResponse: Decodable {
    let id: String
    let transfer: GiantsquidTransfer
}

struct GiantsquidTransfer: Decodable {
    let id: String?
    let amount: String
    let to: GiantsquidDestination?
    let from: GiantsquidDestination?
    let success: Bool?
    let extrinsicHash: String?
    let timestamp: String
    let blockNumber: UInt32?
    let type: String?
    let feeAmount: String?
    let signedData: GiantsquidSignedData?

    var timestampInSeconds: Int64 {
        let locale = LocalizationManager.shared.selectedLocale
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: locale).date(from: timestamp)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }
}

struct GiantsquidSignedData: Decodable {
    let fee: GiantsquidSignedDataFee?
}

struct GiantsquidSignedDataFee: Decodable {
    let `class`: String?
    let weight: UInt32?
    @OptionStringCodable var partialFee: BigUInt?
}

extension GiantsquidTransfer: WalletRemoteHistoryItemProtocol {
    var identifier: String {
        id.or(extrinsicHash.or(timestamp + amount))
    }

    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { timestampInSeconds }
    var label: WalletRemoteHistorySourceLabel {
        .transfers
    }

    func createTransactionForAddress(
        _ address: String,
        chain _: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            transfer: self,
            address: address,
            asset: asset
        )
    }
}
