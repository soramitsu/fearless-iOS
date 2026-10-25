import BigInt
import SSFUtils

struct DepositLiquidityCall: Codable {
    let dexId: String
    let assetA: SoraAssetId
    let assetB: SoraAssetId
    @StringCodable var desiredA: BigUInt
    @StringCodable var desiredB: BigUInt
    @StringCodable var minA: BigUInt
    @StringCodable var minB: BigUInt

    enum CodingKeys: String, CodingKey {
        case dexId
        case assetA = "inputAssetA"
        case assetB = "inputAssetB"
        case desiredA = "inputADesired"
        case desiredB = "inputBDesired"
        case minA = "inputAMin"
        case minB = "inputBMin"
    }
}
