import Foundation

final class RewardCalculatorFacade {
    static let sharedService: RewardCalculatorServiceProtocol = {
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let providerFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        return RewardCalculatorService(
            eraValidatorsService: EraValidatorFacade.sharedService,
            logger: logger,
            operationManager: operationManager,
            providerFactory: providerFactory,
            runtimeCodingService: RuntimeRegistryFacade.sharedService,
            storageFacade: storageFacade
        )
    }()
}
