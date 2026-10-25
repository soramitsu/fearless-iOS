import Foundation
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

final class StorageKeyDataExtractor {
    private let runtimeService: RuntimeCodingServiceProtocol

    private lazy var storageKeyFactory = StorageKeyFactory()

    init(runtimeService: RuntimeCodingServiceProtocol) {
        self.runtimeService = runtimeService
    }

    func extractKey<T: Decodable>(
        storageKey: Data,
        storagePath: any StorageCodingPathProtocol,
        type: MapKeyType
    ) async throws -> T {
        let storageKeyHex = storageKey.toHex()
        let parameterHex = type.extractKeys(from: storageKeyHex)

        let coderFactory = try await runtimeService.fetchCoderFactory()

        guard let entry = coderFactory.metadata.getStorageMetadata(
            in: storagePath.moduleName,
            storageName: storagePath.itemName
        ) else {
            throw StorageKeyEncodingOperationError.invalidStoragePath
        }

        let resolver = coderFactory.metadata.schemaResolver
        let keyName: String
        switch type {
        case .assetIds, .accountPoolsKey, .poolProvidersKey:
            // These selectors reconstruct the complete tuple, not only its last component.
            guard let name = try entry.type.keyName(schemaResolver: resolver) else {
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }
            keyName = name
        default:
            let hasher: StorageHasher
            switch entry.type {
            case let .map(map):
                keyName = map.key
                hasher = map.hasher
            case let .doubleMap(map):
                keyName = map.key2
                hasher = map.key2Hasher
            case let .nMap(map):
                let keys = try map.keys(using: resolver)
                guard keys.count == map.hashers.count,
                      let name = keys.last,
                      let lastHasher = map.hashers.last else
                {
                    throw StorageKeyEncodingOperationError.incompatibleStorageType
                }
                keyName = name
                hasher = lastHasher
            case .plain:
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }

            // A fixed-width selector extracts the final key component. Hash-only keys
            // cannot be decoded back to that component, even when the digest has its width.
            let hashLength: Int
            switch hasher {
            case .identity: hashLength = 0
            case .twox64Concat: hashLength = 8
            case .blake128Concat: hashLength = 16
            default: throw StorageKeyEncodingOperationError.incompatibleStorageType
            }
            guard storageKey.count >= 32 + hashLength + type.bytesCount else {
                throw StorageKeyEncodingOperationError.incompatibleStorageType
            }
        }

        let parameter = try Data(hexStringSSF: parameterHex)
        let decoder = try coderFactory.createDecoder(from: parameter)
        let result: T = try decoder.read(of: keyName)
        guard decoder.remained == 0 else {
            throw StorageKeyEncodingOperationError.incompatibleStorageType
        }
        return result
    }
}
