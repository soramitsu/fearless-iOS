import Foundation

final class ChainRegistryFacade {
    static let sharedRegistry: ChainRegistryProtocol = ChainRegistryFactory.createDefaultRegistry()
}
