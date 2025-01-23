import Foundation
import SSFUtils

protocol MultipleStorageResponseValueExtractor {
    func extractValue<T: Decodable, K: Decodable & ScaleCodable>(
        request: MultipleRequest,
        storageResponse: [StorageResponse<T>]
    ) async throws -> [K: T]
}
