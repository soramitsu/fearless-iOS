import Foundation
import SSFModels
import SSFRuntimeCodingService

public enum PolkadotRuntimeProviderError: Error {
    case error(reason: String)
}

public final class PolkadotRuntimeProvider {
    public init() {}

    public func buildRuntimeProvider() async throws -> RuntimeProviderProtocol {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        let chainMetadata = try RuntimeMetadataItem(
            chain: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
            version: 1,
            txVersion: 1,
            metadata: extractMetadata()
        )
        let runtimeService = try RuntimeProvider(
            operationQueue: operationQueue,
            usedRuntimePaths: [:],
            chainMetadata: chainMetadata,
            chainTypes: extractTypes()
        )
        let _ = try await runtimeService.readySnapshot()
        return runtimeService
    }

    private func extractMetadata() throws -> Data {
        guard let url = Bundle.module.url(forResource: "polkadot-v14-metadata", withExtension: "") else {
            throw PolkadotRuntimeProviderError.error(reason: "Can't find metadata file")
        }

        let hex = try String(contentsOf: url)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let expectedData = try Data(hexStringSSF: hex)
        return expectedData
    }

    private func extractTypes() throws -> Data {
        guard let url = Bundle.module.url(forResource: "types", withExtension: "json") else {
            throw PolkadotRuntimeProviderError.error(reason: "Can't find types file")
        }
        let chainsData = try Data(contentsOf: url)
        return chainsData
    }
}
