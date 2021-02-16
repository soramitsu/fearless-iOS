import Foundation
import RobinHood

protocol SubstrateDataProviderFactoryProtocol {
    func createRuntimeMetadataItemProvider(for chain: Chain) -> StreamableProvider<RuntimeMetadataItem>
}

final class SubstrateDataProviderFactory: SubstrateDataProviderFactoryProtocol {
    let facade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(facade: StorageFacadeProtocol,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol) {
        self.facade = facade
        self.operationManager = operationManager
        self.logger = logger
    }

    func createRuntimeMetadataItemProvider(for chain: Chain) -> StreamableProvider<RuntimeMetadataItem> {
        let identifier = chain.genesisHash

        let filter = NSPredicate.filterRuntimeMetadataItemsBy(identifier: identifier)
        let storage: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            facade.createRepository(filter: filter)
        let source = EmptyStreamableSource()
        let observable = CoreDataContextObservable(service: facade.databaseService,
                                                   mapper: AnyCoreDataMapper(storage.dataMapper),
                                                   predicate: { $0.identifier == identifier })

        observable.start { error in
            if let error = error {
                self.logger.error("Can't start storage observing: \(error)")
            }
        }

        let operationManager = OperationManagerFacade.sharedManager

        return StreamableProvider(source: AnyStreamableSource(source),
                                  repository: AnyDataProviderRepository(storage),
                                  observable: AnyDataProviderRepositoryObservable(observable),
                                  operationManager: operationManager)
    }
}
