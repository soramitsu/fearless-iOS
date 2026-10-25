import BigInt
import Foundation
import SSFModels
import SSFUtils

struct LiberlandBridgeProxyBurnCall: Codable {
    let networkId: BridgeTypesSubNetworkId
    let assetId: LiberlandAssetId
    let recipient: BridgeTypesGenericAccount
    @StringCodable var amount: BigUInt
}

enum LiberlandAssetId: Codable {
    case lld
    case asset(String)
    
    init(currencyId: String?) {
        guard let currencyId else {
            self = .lld
            return
        }
        self = .asset(currencyId)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        
        switch self {
        case .lld:
            try container.encode("LLD")
            try container.encodeNil()
        case let .asset(id):
            try container.encode("Asset")
            try container.encode(id)
        }
    }
}
