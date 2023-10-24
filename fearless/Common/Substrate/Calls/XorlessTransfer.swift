import Foundation
import BigInt
import SSFUtils

struct XorlessTransfer: Codable {
    let dexId: String
    let assetId: SoraAssetId
    let receiver: Data
    @StringCodable var amount: BigUInt
    @StringCodable var desiredXorAmount: BigUInt
    @StringCodable var maxAmountIn: BigUInt
    let selectedSourceTypes: [[String?]]
    let filterMode: PolkaswapCallFilterModeType
    let additionalData: Data

    enum CodingKeys: String, CodingKey {
        case dexId
        case assetId
        case receiver
        case amount
        case desiredXorAmount = "desired_xor_amount"
        case maxAmountIn = "max_amount_in"
        case selectedSourceTypes = "selected_source_types"
        case filterMode = "filter_mode"
        case additionalData = "additional_data"
    }
}
