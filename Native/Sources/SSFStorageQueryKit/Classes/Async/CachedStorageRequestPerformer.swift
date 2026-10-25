import Foundation

public struct CachedStorageRequestTrigger: OptionSet {
    public typealias RawValue = UInt8
    public private(set) var rawValue: UInt8

    public static var onPerform: CachedStorageRequestTrigger {
        CachedStorageRequestTrigger(rawValue: 1 << 0)
    }

    public static var onCache: CachedStorageRequestTrigger {
        CachedStorageRequestTrigger(rawValue: 1 << 1)
    }

    public static var onAll: CachedStorageRequestTrigger = [.onCache, onPerform]

    public init(rawValue: CachedStorageRequestTrigger.RawValue) {
        self.rawValue = rawValue
    }
}

/// Coordinates cache/remote delivery for all three request shapes. Every producer
/// path terminates the stream, and a cancelled consumer cancels its producer task.
enum CachedStorageStream {
    typealias Continuation<Value> = AsyncThrowingStream<CachedStorageResponse<Value>, Error>.Continuation

    static func make<Value>(
        options: CachedStorageRequestTrigger,
        readCache: @escaping (Continuation<Value>) async throws -> Void,
        fetchRemote: @escaping () async throws -> Value?
    ) -> AsyncThrowingStream<CachedStorageResponse<Value>, Error> {
        let readsCache = options.isEmpty || options.contains(.onCache)
        let readsRemote = options.isEmpty || options.contains(.onPerform)
        return AsyncThrowingStream { continuation in
            let producer = Task {
                do {
                    try Task.checkCancellation()
                    if readsCache {
                        do {
                            try await readCache(continuation)
                        } catch {
                            // A cache is optional when a fresh value was requested. Cancellation
                            // is not a cache miss, and cache-only callers must receive the error.
                            if error is CancellationError || Task.isCancelled || !readsRemote {
                                throw error
                            }
                        }
                    }
                    try Task.checkCancellation()
                    if readsRemote {
                        let value = try await fetchRemote()
                        try Task.checkCancellation()
                        continuation.yield(CachedStorageResponse(value: value, type: .remote))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }
}
