import Foundation

enum StorageResponseValueExtractorError: Error {
    case invalidResponse
}

protocol StorageResponseValueExtractor {
    func extractValue<T: Decodable>(storageResponse: [StorageResponse<T>]) throws -> T?
}
