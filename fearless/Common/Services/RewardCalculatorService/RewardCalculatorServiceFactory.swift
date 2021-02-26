import Foundation

final class RewardCalculatorServiceFactory {
    static func createService(runtime: RuntimeCodingServiceProtocol) -> RewardCalculatorServiceProtocol {
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        let eraValidatorsService = EraValidatorFactory.createService(runtime: runtime)

        return RewardCalculatorService(
            eraValidatorsService: eraValidatorsService,
            logger: logger,
            operationManager: operationManager,
            providerFactory: providerFactory,
            runtimeCodingService: runtime,
            storageFacade: storageFacade)
    }
}
