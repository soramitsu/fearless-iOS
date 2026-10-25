import Foundation
import SSFRuntimeCodingService
import SSFUtils
import SSFModels

final class SimpleKeyEncodingWorker: StorageKeyEncoder {
    private let codingFactory: RuntimeCoderFactoryProtocol
    private let path: any StorageCodingPathProtocol
    private let storageKeyFactory: StorageKeyFactoryProtocol

    init(
        codingFactory: RuntimeCoderFactoryProtocol,
        path: any StorageCodingPathProtocol,
        storageKeyFactory: StorageKeyFactoryProtocol
    ) {
        self.codingFactory = codingFactory
        self.path = path
        self.storageKeyFactory = storageKeyFactory
    }

    func performEncoding() throws -> [Data] {
        return [try storageKeyFactory.createStorageKey(moduleName: path.moduleName, storageName: path.itemName)]
    }
}
