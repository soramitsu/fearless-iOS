import Foundation

enum RuntimeSpecVersion: UInt32 {
    case v9370 = 9370
    case v9380 = 9380
    case v9390 = 9390
    case v9420 = 9420
    case v9430 = 9430

    static let defaultVersion: RuntimeSpecVersion = .v9390

    init?(rawValue: UInt32) {
        switch rawValue {
        case 9370:
            self = .v9370
        case 9380:
            self = .v9380
        case 9390:
            self = .v9390
        case 9420:
            self = .v9420
        case 9430:
            self = .v9430
        default:
            self = RuntimeSpecVersion.defaultVersion
        }
    }

    // Helper methods

    func higherOrEqualThan(_ version: RuntimeSpecVersion) -> Bool {
        rawValue >= version.rawValue
    }

    func lowerOrEqualThan(_ version: RuntimeSpecVersion) -> Bool {
        rawValue <= version.rawValue
    }
}
