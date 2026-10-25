import Foundation
import SSFUtils

public struct DexInfos: Decodable {
    var baseAssetId: PolkaswapDexInfoAssetId
    var syntheticBaseAssetId: PolkaswapDexInfoAssetId
    var isPublic: Bool
}

public struct PolkaswapDexInfoAssetId: Codable, Hashable {
    @ArrayCodable public var code: String
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}

extension PolkaswapDexInfoAssetId: ScaleCodable {
    public func encode(scaleEncoder: ScaleEncoding) throws {
        try code.encode(scaleEncoder: scaleEncoder)
    }
    
    public init(scaleDecoder: ScaleDecoding) throws {
        code = try String(scaleDecoder: scaleDecoder)
    }
}
