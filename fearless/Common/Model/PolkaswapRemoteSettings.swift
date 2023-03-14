import Foundation
import RobinHood

struct PolkaswapRemoteSettings: Codable, Identifiable {
    var identifier: String { version }

    let version: String
    let availableDexIds: [PolkaswapDex]
    let availableSources: [LiquiditySourceType]
    let forceSmartIds: [String]
    let xstusdId: String

    enum CodingKeys: String, CodingKey {
        case version
        case availableDexIds
        case availableSources
        case forceSmartIds
        case xstusdId
    }
}
