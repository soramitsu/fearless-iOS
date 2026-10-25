import Foundation
import SSFUtils
import SSFRuntimeCodingService

public protocol PrefixResponseValueExtractor {
    func extractValue<K: Decodable, T: Decodable>(
        request: PrefixRequest,
        storageResponse: [StorageResponse<T>]
    ) async throws -> [K: T]?
}

public final class PrefixStorageResponseValueExtractor: PrefixResponseValueExtractor {
    private let runtimeService: RuntimeCodingServiceProtocol

    init(runtimeService: RuntimeCodingServiceProtocol) {
        self.runtimeService = runtimeService
    }

    public func extractValue<K: Decodable, T: Decodable>(
        request: PrefixRequest,
        storageResponse: [StorageResponse<T>]
    ) async throws -> [K: T]? {
        var dict: [K: T] = [:]
        let keyExtractor = StorageKeyDataExtractor(runtimeService: runtimeService)
        print("[\(request.storagePath)] storage response: ", storageResponse.count)

        try await storageResponse.asyncForEach {
            let id: K = try await keyExtractor.extractKey(
                storageKey: $0.key,
                storagePath: request.storagePath,
                type: request.keyType
            )

            dict[id] = $0.value
        }
        
        print("[\(request.storagePath)] result dict: ", dict.count)

        return dict
    }
}
