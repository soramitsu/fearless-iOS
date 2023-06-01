import Foundation
import SSFUtils

struct DexIdInfo: Decodable {
    let isPublic: Bool
    let baseAssetId: PolkaswapDexInfoAssetId
}

struct PolkaswapDexInfoAssetId: Decodable {
    @StringCodable var code: String
}
