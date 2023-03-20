import Foundation

enum RuntimeSpecVersion: UInt32 {
    case v9370
    case v9380
    case v9390

    static let defaultVersion: RuntimeSpecVersion = .v9390

    init?(rawValue: UInt32) {
        switch rawValue {
        case 9370:
            self = .v9370
        case 9380:
            self = .v9380
        case 9390:
            self = .v9390
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
