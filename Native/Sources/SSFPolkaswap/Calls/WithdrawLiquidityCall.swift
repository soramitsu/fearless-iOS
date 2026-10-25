import BigInt
import SSFUtils

struct WithdrawLiquidityCall: Codable {
    let dexId: String
    let assetA: SoraAssetId
    let assetB: SoraAssetId
    @StringCodable var assetDesired: BigUInt
    @StringCodable var minA: BigUInt
    @StringCodable var minB: BigUInt

    enum CodingKeys: String, CodingKey {
        case dexId
        case assetA = "outputAssetA"
        case assetB = "outputAssetB"
        case assetDesired = "markerAssetDesired"
        case minA = "outputAMin"
        case minB = "outputBMin"
    }
}
