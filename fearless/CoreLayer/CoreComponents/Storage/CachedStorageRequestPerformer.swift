import Foundation

public struct CachedStorageRequestTrigger: OptionSet {
    public typealias RawValue = UInt8
    public private(set) var rawValue: UInt8

    public static var onPerform: CachedStorageRequestTrigger { CachedStorageRequestTrigger(rawValue: 1 << 0) }
    public static var onCache: CachedStorageRequestTrigger { CachedStorageRequestTrigger(rawValue: 1 << 1) }
    public static var onAll: CachedStorageRequestTrigger = [.onCache, onPerform]

    public init(rawValue: CachedStorageRequestTrigger.RawValue) {
        self.rawValue = rawValue
    }
}
