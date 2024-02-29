import Foundation
import SSFUtils
import SSFModels

// protocol StorageRequestKeyFactory {
//    func createKeyFor(
//        params: StorageRequestWorkerType,
//        storagePath: any StorageCodingPathProtocol
//    ) throws -> Data
// }
//
// final class StorageRequestKeyFactoryDefault: StorageRequestKeyFactory {
//    private lazy var storageKeyFactory: StorageKeyFactoryProtocol = {
//        StorageKeyFactory()
//    }()
//
//    private lazy var encoder = JSONEncoder()
//
//    func createKeyFor(
//        params: StorageRequestWorkerType,
//        storagePath: any StorageCodingPathProtocol
//    ) throws -> Data {
//        let storagePathKey = try storageKeyFactory.createStorageKey(
//            moduleName: storagePath.moduleName,
//            storageName: storagePath.itemName
//        )
//
//        switch params {
//        case let .nMap(params):
//            let keys = try params.reduce([], +).map { try encoder.encode($0.value) }
//            let storageKey = try keys.map {
//                try storageKeyFactory.createStorageKey(
//                    moduleName: storagePath.moduleName,
//                    storageName: storagePath.itemName,
//                    key: $0,
//                    hasher: .blake128
//                )
//            }.joined()
//            return storagePathKey + storageKey
//        case let .encodable(params):
//            let keys = try params.map { try encoder.encode($0) }
//            let storageKey = try keys.map {
//                try storageKeyFactory.createStorageKey(
//                    moduleName: storagePath.moduleName,
//                    storageName: storagePath.itemName,
//                    key: $0,
//                    hasher: .blake128
//                )
//            }.joined()
//            return storagePathKey + storageKey
//        case .simple:
//            return storagePathKey
//        }
//    }
// }
