import Foundation
import RobinHood
import SSFRuntimeCodingService

// Minimal test double for SSF fearless.RuntimeProviderProtocol used by tests.
// Tests only assert identity and call setup/cleanup; coder factory APIs are not exercised.
final class DummyRuntimeProvider: fearless.RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    var snapshot: RuntimeSnapshot?

    func setup() {}
    func cleanup() {}

    func readySnapshot() async throws -> RuntimeSnapshot { throw RuntimeProviderError.providerUnavailable }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { BaseOperation() }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { throw RuntimeProviderError.providerUnavailable }
}

// Preserve historical test naming that expected a generated mock
typealias MockRuntimeProviderProtocol = DummyRuntimeProvider

