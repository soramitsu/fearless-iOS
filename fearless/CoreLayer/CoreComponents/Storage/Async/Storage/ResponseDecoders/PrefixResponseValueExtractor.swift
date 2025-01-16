import Foundation
import SSFRuntimeCodingService
import SSFUtils

protocol PrefixResponseValueExtractor {
    func extractValue<K: Decodable, T: Decodable>(
        request: PrefixRequest,
        storageResponse: [StorageResponse<T>]
    ) async throws -> [K: T]?
}

final class PrefixStorageResponseValueExtractor: PrefixResponseValueExtractor {
    private let runtimeService: RuntimeCodingServiceProtocol

    init(runtimeService: RuntimeCodingServiceProtocol) {
        self.runtimeService = runtimeService
    }

    func extractValue<K: Decodable, T: Decodable>(
        request: PrefixRequest,
        storageResponse: [StorageResponse<T>]
    ) async throws -> [K: T]? {
        var dict: [K: T] = [:]
        let keyExtractor = StorageKeyDataExtractor(runtimeService: runtimeService)

        try await storageResponse.asyncForEach {
            let id: K = try await keyExtractor.extractKey(
                storageKey: $0.key,
                storagePath: request.storagePath,
                type: request.keyType
            )

            dict[id] = $0.value
        }

        return dict
    }
}
