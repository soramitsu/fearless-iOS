import Foundation

final class EraValidatorFacade {
    static let sharedService: EraValidatorServiceProtocol = {
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        return EraValidatorService(storageFacade: SubstrateDataStorageFacade.shared,
                                   runtimeCodingService: RuntimeRegistryFacade.sharedService,
                                   providerFactory: providerFactory,
                                   operationManager: operationManager,
                                   logger: logger)
    }()
}
