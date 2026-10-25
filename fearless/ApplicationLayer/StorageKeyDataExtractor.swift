import Foundation
import SSFUtils
import SSFRuntimeCodingService
import SSFModels

final class StorageKeyDataExtractor {
    private let runtimeService: RuntimeCodingServiceProtocol

    init(runtimeService: RuntimeCodingServiceProtocol) {
        self.runtimeService = runtimeService
    }

    func extractKey<T: Decodable>(
        storageKey: Data,
        storagePath: StorageCodingPath,
        type: MapKeyType
    ) async throws -> T {
        let storageKeyHex = storageKey.toHex()
        let parameterHex = type.extractKeys(from: storageKeyHex)

        let coderFactory = try await runtimeService.fetchCoderFactory()

        let storagePathMetadata = coderFactory.metadata.getStorageMetadata(in: storagePath.moduleName, storageName: storagePath.itemName)

        guard let keyName = try storagePathMetadata?.type.keyName(schemaResolver: coderFactory.metadata.schemaResolver) else {
            throw ConvenienceError(error: "type not found")
        }

        let parameter = try Data(hexStringSSF: parameterHex)
        let decoder = try coderFactory.createDecoder(from: parameter)
        return try decoder.read(of: keyName)
    }
}
