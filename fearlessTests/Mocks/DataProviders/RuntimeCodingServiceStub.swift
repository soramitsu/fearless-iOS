import Foundation
@testable import fearless
import RobinHood
import SSFRuntimeCodingService
import SSFUtils

final class RuntimeCodingServiceStub {
    let factory : RuntimeCoderFactoryProtocol

    init(factory: RuntimeCoderFactoryProtocol) {
        self.factory = factory
    }
}

// Minimal test-only RuntimeCoderFactory implementation to avoid using
// inaccessible initializers from SSFRuntimeCodingService.
final class TestRuntimeCoderFactory: RuntimeCoderFactoryProtocol {
    private let catalog: TypeRegistryCatalogProtocol
    let specVersion: UInt32
    let txVersion: UInt32
    let metadata: RuntimeMetadata

    init(catalog: TypeRegistryCatalogProtocol, specVersion: UInt32, txVersion: UInt32, metadata: RuntimeMetadata) {
        self.catalog = catalog
        self.specVersion = specVersion
        self.txVersion = txVersion
        self.metadata = metadata
    }

    func createEncoder() -> DynamicScaleEncoding {
        DynamicScaleEncoder(registry: catalog, version: UInt64(specVersion))
    }

    func createDecoder(from data: Data) throws -> DynamicScaleDecoding {
        try DynamicScaleDecoder(data: data, registry: catalog, version: UInt64(specVersion))
    }
}

extension RuntimeCodingServiceStub: RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? {
        return nil
    }
    
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { self.factory }
    }
    
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        factory
    }
    
    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { self.factory }
    }
}

extension RuntimeCodingServiceStub {
    static func createWestendCodingFactory(
        specVersion: UInt32 = 48,
        txVersion: UInt32 = 4,
        metadataVersion: UInt32? = nil
    ) throws -> RuntimeCoderFactoryProtocol {
        var metadataFilename = "westend-metadata"
        if let version = metadataVersion {
            metadataFilename += "-v\(version)"
        }
        let runtimeMetadata = try RuntimeHelper.createRuntimeMetadata(metadataFilename)
        let typeCatalog = try RuntimeHelper.createTypeRegistryCatalog(
            from: "runtime-default",
            networkName: "runtime-westend",
            runtimeMetadata: runtimeMetadata
        )

        return TestRuntimeCoderFactory(
            catalog: typeCatalog,
            specVersion: specVersion,
            txVersion: txVersion,
            metadata: runtimeMetadata
        )
    }

    static func createWestendService(
        specVersion: UInt32 = 48,
        txVersion: UInt32 = 4
    ) throws -> RuntimeCodingServiceProtocol {
        let factory = try createWestendCodingFactory(specVersion: specVersion, txVersion: txVersion)
        return RuntimeCodingServiceStub(factory: factory)
    }
}
