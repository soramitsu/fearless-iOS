import Foundation
import SSFUtils

public struct AssetIdPair: Codable, Hashable {
    public let baseAssetId: PolkaswapDexInfoAssetId
    public let targetAssetId: PolkaswapDexInfoAssetId
    
    public init(baseAssetIdCode: String, targetAssetIdCode: String) {
        self.baseAssetId = PolkaswapDexInfoAssetId(code: baseAssetIdCode)
        self.targetAssetId = PolkaswapDexInfoAssetId(code: targetAssetIdCode)
    }
    
    public init(baseAssetId: PolkaswapDexInfoAssetId, targetAssetId: PolkaswapDexInfoAssetId) {
        self.baseAssetId = baseAssetId
        self.targetAssetId = targetAssetId
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.baseAssetId = try container.decode(PolkaswapDexInfoAssetId.self)
        self.targetAssetId = try container.decode(PolkaswapDexInfoAssetId.self)
    }
    
    public var poolId: String {
        "\(baseAssetId.code)-\(targetAssetId.code)"
    }
}

extension AssetIdPair: ScaleCodable {
    public init(scaleDecoder: ScaleDecoding) throws {
        baseAssetId = try PolkaswapDexInfoAssetId(scaleDecoder: scaleDecoder)
        targetAssetId = try PolkaswapDexInfoAssetId(scaleDecoder: scaleDecoder)
    }

    public func encode(scaleEncoder: ScaleEncoding) throws {
        try baseAssetId.encode(scaleEncoder: scaleEncoder)
        try targetAssetId.encode(scaleEncoder: scaleEncoder)
    }
}
