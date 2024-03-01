import Foundation
import SSFUtils

final class StorageKeyDataExtractor {
    private let runtimeService: RuntimeCodingServiceProtocol

    private lazy var storageKeyFactory = {
        StorageKeyFactory()
    }()

    init(runtimeService: RuntimeCodingServiceProtocol) {
        self.runtimeService = runtimeService
    }

    func extractKey<T: Decodable & ScaleCodable>(
        storageKey: Data,
        storagePath: StorageCodingPath,
        type: RuntimeType
    ) async throws -> T {
        let storageKeyHex = storageKey.toHex()
        let bytesPerHexSymbol = 2
        let parameterHex = String(storageKeyHex.suffix(type.bytesCount * bytesPerHexSymbol))

        let coderFactory = try await runtimeService.fetchCoderFactory()

        let storagePathMetadata = coderFactory.metadata.getStorageMetadata(for: storagePath)

        guard let keyName = try storagePathMetadata?.type.keyName(schemaResolver: coderFactory.metadata.schemaResolver) else {
            throw ConvenienceError(error: "type not found")
        }

        let parameter = try Data(hexStringSSF: parameterHex)
        let decoder = try coderFactory.createDecoder(from: parameter)
        return try decoder.read(of: keyName)
    }
}
