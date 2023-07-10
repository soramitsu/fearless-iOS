import Foundation

enum UtilityConstants {
    #if F_DEV
        static let inactiveSessionDropTimeInSeconds: TimeInterval = 60
    #else
        static let inactiveSessionDropTimeInSeconds: TimeInterval = 1200
    #endif
}
