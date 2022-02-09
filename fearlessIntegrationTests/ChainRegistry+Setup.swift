import Foundation
@testable import fearless

extension ChainRegistryFacade {
    static func setupForIntegrationTest(
        with storageFacade: StorageFacadeProtocol
    ) -> ChainRegistryProtocol {
        let chainRegistry = ChainRegistryFactory.createDefaultRegistry(from: storageFacade)
        chainRegistry.syncUp()

        let semaphore = DispatchSemaphore(value: 0)
        chainRegistry.chainsSubscribe(
            self, runningInQueue: .global()
        ) { changes in
            if !changes.isEmpty {
                semaphore.signal()
            }
        }

        semaphore.wait()

        return chainRegistry
    }
}
