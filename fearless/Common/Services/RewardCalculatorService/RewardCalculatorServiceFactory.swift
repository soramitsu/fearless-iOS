import Foundation

final class RewardCalculatorServiceFactory {
    static func createService(runtime: RuntimeCodingServiceProtocol,
                              validators: EraValidatorServiceProtocol) -> RewardCalculatorServiceProtocol {
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        return RewardCalculatorService(
            eraValidatorsService: validators,
            logger: logger,
            operationManager: operationManager,
            providerFactory: providerFactory,
            runtimeCodingService: runtime,
            storageFacade: storageFacade)
    }
}
