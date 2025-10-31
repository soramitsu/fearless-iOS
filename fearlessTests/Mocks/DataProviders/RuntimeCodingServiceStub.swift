import Foundation
@testable import fearless
import RobinHood
import SSFRuntimeCodingService
import SSFUtils
import SSFModels

final class RuntimeCodingServiceStub: RuntimeCodingServiceProtocol {
    let factory : RuntimeCoderFactoryProtocol

    init(factory: RuntimeCoderFactoryProtocol) {
        self.factory = factory
    }

    // MARK: - RuntimeCodingServiceProtocol

    var snapshot: RuntimeSnapshot? { nil }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { self.factory }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        factory
    }
}

extension RuntimeCodingServiceStub {
    private struct FakeRuntimeCoderFactory: RuntimeCoderFactoryProtocol {
        let specVersion: UInt32
        let txVersion: UInt32
        let metadata: RuntimeMetadata
        let catalog: TypeRegistryCatalogProtocol

        func createEncoder() -> DynamicScaleEncoding {
            DynamicScaleEncoder(registry: catalog, version: UInt64(specVersion))
        }

        func createDecoder(from data: Data) throws -> DynamicScaleDecoding {
            try DynamicScaleDecoder(data: data, registry: catalog, version: UInt64(specVersion))
        }
    }

    static func createWestendService() throws -> RuntimeCodingServiceProtocol {
        // Load compact test metadata bundled with tests
        let metadata = try RuntimeHelper.createRuntimeMetadata("runtimeTestMetadata")

        // Build a minimal snapshot using empty versioning types and empty usedRuntimePaths
        let chainTypes = Data("{}".utf8)

        // Build a minimal catalog similar to RuntimeSnapshotFactory
        let json: JSON = .dictionaryValue(["types": .dictionaryValue([:])])
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            JSONEncoder().encode(json),
            versioningData: chainTypes,
            runtimeMetadata: metadata,
            usedRuntimePaths: [:]
        )

        let factory = FakeRuntimeCoderFactory(
            specVersion: 1,
            txVersion: 1,
            metadata: metadata,
            catalog: catalog
        )

        return RuntimeCodingServiceStub(factory: factory)
    }
}
