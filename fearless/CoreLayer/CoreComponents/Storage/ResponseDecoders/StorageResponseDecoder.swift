import Foundation

enum StorageResponseDecoderError: Error {
    case invalidResponse
}

protocol StorageResponseDecoder {
    func decode<T: Decodable>(storageResponse: [StorageResponse<T>]) throws -> T?
}
