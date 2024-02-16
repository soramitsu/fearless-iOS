import Foundation

final class StorageSingleResponseDecoder: StorageResponseDecoder {
    func decode<T>(storageResponse: [StorageResponse<T>]) throws -> T? where T: Decodable {
        guard storageResponse.count <= 1 else {
            throw StorageResponseDecoderError.invalidResponse
        }

        return storageResponse.first?.value
    }
}
