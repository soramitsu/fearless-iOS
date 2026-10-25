import Foundation

final class SingleStorageResponseValueExtractor: StorageResponseValueExtractor {
    func extractValue<T>(storageResponse: [StorageResponse<T>]) throws -> T? where T: Decodable {
        guard storageResponse.count <= 1 else {
            throw StorageResponseValueExtractorError.invalidResponse
        }

        return storageResponse.first?.value
    }
}
