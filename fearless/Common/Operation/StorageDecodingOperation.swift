import Foundation
import FearlessUtils
import RobinHood

enum StorageDecodingOperationError: Error {
    case missingRequiredParams
    case invalidStoragePath
}

final class StorageDecodingOperation<T: Decodable>: BaseOperation<T> {
    var data: Data?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    init(path: StorageCodingPath, data: Data? = nil) {
        self.path = path
        self.data = data

        super.init()
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            guard let data = data, let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            guard let entry = factory.metadata.getStorageMetadata(in: path.moduleName,
                                                                  storageName: path.itemName) else {
                throw StorageDecodingOperationError.invalidStoragePath
            }

            let decoder = try factory.createDecoder(from: data)
            let item: T = try decoder.read(of: entry.type.typeName)
            result = .success(item)
        } catch {
            result = .failure(error)
        }
    }
}

final class StorageDecodingListOperation<T: Decodable>: BaseOperation<[T]> {
    var dataList: [Data]?
    var codingFactory: RuntimeCoderFactoryProtocol?

    let path: StorageCodingPath

    init(path: StorageCodingPath, dataList: [Data]? = nil) {
        self.path = path
        self.dataList = dataList

        super.init()
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            guard let dataList = dataList, let factory = codingFactory else {
                throw StorageDecodingOperationError.missingRequiredParams
            }

            guard let entry = factory.metadata.getStorageMetadata(in: path.moduleName,
                                                                  storageName: path.itemName) else {
                throw StorageDecodingOperationError.invalidStoragePath
            }

            let items: [T] = try dataList.map { data in
                let decoder = try factory.createDecoder(from: data)
                return try decoder.read(of: entry.type.typeName)
            }

            result = .success(items)
        } catch {
            result = .failure(error)
        }
    }
}
