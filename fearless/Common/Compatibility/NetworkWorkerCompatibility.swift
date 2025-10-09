import Foundation
import SSFNetwork

// Provide a concrete type expected by assemblies in the app code.
public typealias NetworkWorkerImpl = NetworkWorkerDefault

// Lightweight cache control placeholders to satisfy existing interfaces.
public enum CachedNetworkRequestTrigger {
    case none
}

public struct CachedNetworkResponse<T: Decodable> {
    public let data: T
    public init(data: T) { self.data = data }
}

public extension NetworkWorker {
    func performRequest<T: Decodable>(
        with config: RequestConfig,
        withCacheOptions _: CachedNetworkRequestTrigger
    ) async throws -> AsyncThrowingStream<CachedNetworkResponse<T>, Error> {
        let value: T = try await performRequest(with: config)
        return AsyncThrowingStream { continuation in
            continuation.yield(CachedNetworkResponse(data: value))
            continuation.finish()
        }
    }
}
