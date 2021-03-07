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
    func fetchCoderFactoryOperation(with timeout: TimeInterval,
                                    closure: RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { self.factory }
    }
}

extension RuntimeCodingServiceStub {
    static func createWestendService() throws -> RuntimeCodingServiceProtocol {
        let runtimeMetadata = try RuntimeHelper.createRuntimeMetadata("westend-metadata")
        let typeCatalog = try RuntimeHelper.createTypeRegistryCatalog(from: "runtime-default",
                                                                      networkName: "runtime-westend",
                                                                      runtimeMetadata: runtimeMetadata)

        let factory = RuntimeCoderFactory(catalog: typeCatalog,
                                          specVersion: 48,
                                          txVersion: 4,
                                          metadata: runtimeMetadata)

        return RuntimeCodingServiceStub(factory: factory)
    }
}
