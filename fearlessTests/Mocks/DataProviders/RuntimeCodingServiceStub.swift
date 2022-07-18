import Foundation
@testable import fearless
import RobinHood

final class RuntimeCodingServiceStub {
    let factory : RuntimeCoderFactoryProtocol

    init(factory: RuntimeCoderFactoryProtocol) {
        self.factory = factory
    }
}

extension RuntimeCodingServiceStub: RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? {
        return nil
    }
    
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { self.factory }
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

        return RuntimeCoderFactory(
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
