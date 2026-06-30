import Foundation
@testable import fearless
import XCTest

extension ChainRegistryFacade {
    static func skipUnlessLiveIntegrationEnabled() throws {
        guard ProcessInfo.processInfo.environment["FEARLESS_RUN_LIVE_INTEGRATION_TESTS"] == "1" else {
            throw XCTSkip("Set FEARLESS_RUN_LIVE_INTEGRATION_TESTS=1 to run live chain-registry integration tests")
        }
    }

    static func setupForIntegrationTest(
        with storageFacade: StorageFacadeProtocol
    ) -> ChainRegistryProtocol {
        _ = storageFacade
        let chainRegistry = sharedRegistry

        let timeout = Date().addingTimeInterval(integrationSetupTimeout)

        if chainRegistry.availableChains.isEmpty {
            chainRegistry.performColdBoot()
        }

        while chainRegistry.availableChains.isEmpty, Date() < timeout {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return chainRegistry
    }

    private static var integrationSetupTimeout: TimeInterval {
        guard
            let rawValue = ProcessInfo.processInfo.environment["FEARLESS_INTEGRATION_SETUP_TIMEOUT_SECONDS"],
            let value = TimeInterval(rawValue)
        else {
            return 30
        }

        return min(max(value, 0), 300)
    }
}
