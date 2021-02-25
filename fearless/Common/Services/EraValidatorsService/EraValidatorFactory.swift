import Foundation

final class EraValidatorFactory {
    static func createService(runtime: RuntimeCodingServiceProtocol) -> EraValidatorServiceProtocol {
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        return EraValidatorService(storageFacade: SubstrateDataStorageFacade.shared,
                                   runtimeCodingService: runtime,
                                   providerFactory: providerFactory,
                                   operationManager: operationManager,
                                   logger: logger)
    }
}
