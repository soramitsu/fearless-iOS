import Foundation
import SSFModels

// enum RuntimeSpecVersion: UInt32, CaseIterable {
//    case v9370 = 9370
//    case v9380 = 9380
//    case v9390 = 9390
//    case v9420 = 9420
//    case v9430 = 9430
//
//    static func defaultVersion(for chain: ChainModel) -> RuntimeSpecVersion {
//        if chain.isPolkadotOrKusama || chain.isWestend {
//            return RuntimeSpecVersion.allCases.last ?? .v9430
//        } else {
//            return .v9370
//        }
//    }
//
//    static func version(for chain: ChainModel, rawValue: UInt32) -> RuntimeSpecVersion? {
//        switch rawValue {
//        case 9370:
//            return .v9370
//        case 9380:
//            return .v9380
//        case 9390:
//            return .v9390
//        case 9420:
//            return .v9420
//        case 9430:
//            return .v9430
//        default:
//            return defaultVersion(for: chain)
//        }
//    }
//
//    // Helper methods
//
//    func higherOrEqualThan(_ version: RuntimeSpecVersion) -> Bool {
//        rawValue >= version.rawValue
//    }
//
//    func lowerOrEqualThan(_ version: RuntimeSpecVersion) -> Bool {
//        rawValue <= version.rawValue
//    }
// }
