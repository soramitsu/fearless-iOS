import Foundation
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

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
        try [storageKeyFactory.createStorageKey(
            moduleName: path.moduleName,
            storageName: path.itemName
        )]
    }
}
