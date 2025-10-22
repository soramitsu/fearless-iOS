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

// Provide only the operation-based API used in tests; do not conform to full protocol with async API
// Fetch operations return the injected factory
extension RuntimeCodingServiceStub {
    var snapshot: RuntimeSnapshot? { nil }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { self.factory }
    }

    func fetchCoderFactoryOperation(with timeout: TimeInterval, closure: RuntimeMetadataClosure?) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { self.factory }
    }
}

extension RuntimeCodingServiceStub {
    // The helpers below are kept commented to avoid using internal initializers in SSFRuntimeCodingService
//    static func createWestendCodingFactory(...) -> RuntimeCoderFactoryProtocol { ... }
//    static func createWestendService(...) -> RuntimeCodingServiceProtocol { ... }
}
