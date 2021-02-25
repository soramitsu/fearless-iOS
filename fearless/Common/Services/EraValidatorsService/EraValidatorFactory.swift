import Foundation

final class EraValidatorFactory {
    static func createService(from chain: Chain) -> EraValidatorServiceProtocol & EraValidatorProviderProtocol {
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        return EraValidatorService(chain: chain,
                                   storageFacade: SubstrateDataStorageFacade.shared,
                                   runtimeCodingService: RuntimeRegistryFacade.sharedService,
                                   providerFactory: providerFactory,
                                   webSocketService: WebSocketService.shared,
                                   operationManager: operationManager,
                                   logger: logger)
    }
}
