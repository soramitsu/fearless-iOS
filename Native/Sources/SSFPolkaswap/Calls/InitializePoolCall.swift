import SSFUtils

struct InitializePoolCall: Codable {
    let dexId: String
    let assetA: SoraAssetId
    let assetB: SoraAssetId
}
