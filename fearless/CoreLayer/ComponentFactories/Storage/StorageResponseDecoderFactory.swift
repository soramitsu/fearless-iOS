import Foundation

protocol StorageResponseDecoderFactory {
    func buildResponseDecoder(for request: some StorageRequest) throws -> StorageResponseDecoder
}

final class BaseStorageResponseDecoderFactory: StorageResponseDecoderFactory {
    func buildResponseDecoder(for request: some StorageRequest) throws -> StorageResponseDecoder {
        switch request.responseType {
        case .single:
            return StorageSingleResponseDecoder()
        }
    }
}
