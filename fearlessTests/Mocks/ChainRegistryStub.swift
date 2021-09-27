import Foundation
@testable import fearless
import RobinHood
import Cuckoo

extension MockChainRegistryProtocol {
    func applyDefault(for chains: Set<ChainModel>) -> MockChainRegistryProtocol {
        stub(self) { stub in
            let availableChainIds = Set(chains.map({ $0.chainId }))
            stub.availableChainIds.get.thenReturn(availableChainIds)

            stub.getConnection(for: any()).then { chainId in
                if availableChainIds.contains(chainId) {
                    return MockConnection()
                } else {
                    return nil
                }
            }

            stub.getRuntimeProvider(for: any()).then { chainId in
                if availableChainIds.contains(chainId) {
                    return MockRuntimeProviderProtocol().applyDefault(for: chainId)
                } else {
                    return nil
                }
            }

            stub.chainsSubscribe(
                any(),
                runningInQueue: any(),
                updateClosure: any()
            ).then { (_, queue, closure) in
                queue.async {
                    let updates = chains.map { DataProviderChange.insert(newItem: $0) }
                    closure(updates)
                }
            }

            stub.chainsUnsubscribe(any()).thenDoNothing()
            stub.syncUp().thenDoNothing()
        }

        return self
    }
}
