import SSFUtils

struct PairRegisterCall: Codable {
    let dexId: String
    let baseAssetId: SoraAssetId
    let targetAssetId: SoraAssetId
}
