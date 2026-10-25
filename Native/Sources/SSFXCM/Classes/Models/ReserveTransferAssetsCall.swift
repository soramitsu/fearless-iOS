import BigInt
import Foundation
import SSFModels
import SSFUtils

struct ReserveTransferAssetsCall: Codable {
    enum CodingKeys: String, CodingKey {
        case destination = "dest"
        case beneficiary
        case assets
        case feeAssetItem = "fee_asset_item"
        case weightLimit = "weight_limit"
    }

    let destination: XcmVersionedMultiLocation
    let beneficiary: XcmVersionedMultiLocation
    let assets: XcmVersionedMultiAssets
    let weightLimit: XcmWeightLimit
    @StringCodable var feeAssetItem: UInt32
}
