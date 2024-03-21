import Foundation

protocol MultipleStorageResponseValueExtractor {
    func extractValue<T: Decodable>(storageResponse: [StorageResponse<T>]) throws -> [T?]
}
