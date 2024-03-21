import Foundation

final class MultipleSingleStorageResponseValueExtractor: MultipleStorageResponseValueExtractor {
    func extractValue<T>(storageResponse: [StorageResponse<T>]) throws -> [T?] where T: Decodable {
        storageResponse.map { $0.value }
    }
}
