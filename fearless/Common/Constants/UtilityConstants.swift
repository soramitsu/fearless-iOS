import Foundation

enum UtilityConstants {
    #if F_DEV
        static let inactiveSessionDropTimeInSeconds: TimeInterval = 180
    #else
        static let inactiveSessionDropTimeInSeconds: TimeInterval = 1200
    #endif
}
