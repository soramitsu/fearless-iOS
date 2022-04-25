import Foundation
import SoraKeystore
import RobinHood

final class CrowdloanSharedState {
    let settings: CrowdloanChainSettings
    let crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        internalSettings: SettingsManagerProtocol = SettingsManager.shared,
        operationManager: OperationManagerProtocol = OperationManagerFacade.sharedManager,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        settings = CrowdloanChainSettings(
            storageFacade: storageFacade,
            settings: internalSettings,
            operationQueue: operationQueue
        )

        crowdloanLocalSubscriptionFactory = CrowdloanLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
    }
}
