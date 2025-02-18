import Foundation

public enum CachedStorageResponseType {
    case cache
    case remote
}

public struct CachedStorageResponse<T> {
    public var value: T?
    public var type: CachedStorageResponseType

    public init(value: T?, type: CachedStorageResponseType) {
        self.value = value
        self.type = type
    }

    public static var empty: CachedStorageResponse<T> {
        CachedStorageResponse(value: nil, type: .cache)
    }

    public func merge(
        with previous: CachedStorageResponse<T>?,
        priorityType: CachedStorageResponseType
    ) -> CachedStorageResponse<T> {
        var type: CachedStorageResponseType
        switch (previous?.type, self.type) {
        case (.cache, .cache):
            type = .cache
        case (.remote, .remote):
            type = .remote
        case (.cache, .remote):
            type = .remote
        case (.remote, .cache):
            type = priorityType
        case (nil, .cache):
            type = .cache
        case (nil, .remote):
            type = .remote
        }

        return CachedStorageResponse(value: value, type: type)
    }
}
