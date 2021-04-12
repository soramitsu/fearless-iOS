import Foundation
import SoraKeystore

final class PayoutRewardsServiceFacade {
    static let sharedService: PayoutRewardsServiceProtocol = {
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared
        let settings = SettingsManager.shared
        let selectedAccount = settings.selectedAccount!.address

        let providerFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let connection = WebSocketService.shared.connection!

        return PayoutRewardsService(
            selectedAccountAddress: selectedAccount,
            runtimeCodingService: RuntimeRegistryFacade.sharedService,
            engine: connection,
            operationManager: operationManager,
            providerFactory: providerFactory,
            logger: logger
        )
    }()
}
