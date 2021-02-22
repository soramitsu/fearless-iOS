import Foundation
import RobinHood
import SoraKeystore

final class RuntimeRegistryFacade {
    static let sharedService: RuntimeRegistryServiceProtocol & RuntimeCodingServiceProtocol = {
        let chain = SettingsManager.shared.selectedConnection.type.chain
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager

        let logger = Logger.shared
        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        let filesRepository = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                          directoryPath: runtimeDirectory)

        return RuntimeRegistryService(chain: chain,
                                      metadataProviderFactory: providerFactory,
                                      dataOperationFactory: DataOperationFactory(),
                                      filesOperationFacade: filesRepository,
                                      operationManager: operationManager,
                                      eventCenter: EventCenter.shared,
                                      logger: Logger.shared)
    }()
}
