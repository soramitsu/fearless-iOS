import Foundation
import RobinHood
import SSFRuntimeCodingService

/// Runtime provider without metadata: every coder-factory read fails at once.
final class CovDRuntimeProviderStub: SSFRuntimeCodingService.RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    var snapshot: RuntimeSnapshot?

    func setup() {}
    func setupHot() {}
    func cleanup() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        BaseOperation()
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable
    }
}
