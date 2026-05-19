import Foundation
@testable import fearless
import XCTest

extension ChainRegistryFacade {
    static func setupForIntegrationTest(
        with storageFacade: StorageFacadeProtocol
    ) -> ChainRegistryProtocol {
        _ = storageFacade
        let chainRegistry = sharedRegistry

        let timeout = Date().addingTimeInterval(30)

        if chainRegistry.availableChains.isEmpty {
            chainRegistry.performColdBoot()
        }

        while chainRegistry.availableChains.isEmpty, Date() < timeout {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return chainRegistry
    }
}
