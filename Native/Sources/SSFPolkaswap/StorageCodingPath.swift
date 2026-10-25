import Foundation
import SSFModels

public enum StorageCodingPath: Equatable, CaseIterable, StorageCodingPathProtocol {
    public var moduleName: String {
        path.moduleName
    }

    public var itemName: String {
        path.itemName
    }

    public var path: (moduleName: String, itemName: String) {
        switch self {
        case .dexInfos:
            return (moduleName: "DEXManager", itemName: "DEXInfos")
        case .userPools:
            return (moduleName: "PoolXYK", itemName: "AccountPools")
        case .poolProperties:
            return (moduleName: "PoolXYK", itemName: "Properties")
        case .poolProviders:
            return (moduleName: "PoolXYK", itemName: "PoolProviders")
        case .poolTotalIssuances:
            return (moduleName: "PoolXYK", itemName: "TotalIssuances")
        case .poolReserves:
            return (moduleName: "PoolXYK", itemName: "Reserves")
        }
    }

    case dexInfos
    case userPools
    case poolProperties
    case poolProviders
    case poolTotalIssuances
    case poolReserves
}
