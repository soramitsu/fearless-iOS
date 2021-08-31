import Foundation
import RobinHood
import SoraKeystore

final class RuntimeRegistryFacade {
    static let sharedService: RuntimeRegistryServiceProtocol & RuntimeCodingServiceProtocol = {
        let chain = SettingsManager.shared.selectedConnection.type.chain

        return RuntimeRegistryService(
            chain: chain,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )
    }()
}
