import Foundation
import SSFChainRegistry

final class ChainRegistryFacade {
    static let sharedRegistry: ChainRegistryProtocol & SSFChainRegistry.ChainRegistryProtocol = ChainRegistryFactory.createDefaultRegistry()
}
