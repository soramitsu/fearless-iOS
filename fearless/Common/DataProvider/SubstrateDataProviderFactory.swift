import Foundation
import RobinHood

protocol SubstrateDataProviderFactoryProtocol {
    func createStashItemProvider(for address: String) -> StreamableProvider<StashItem>
    func createRuntimeMetadataItemProvider(for chain: Chain) -> StreamableProvider<RuntimeMetadataItem>
    func createStorageProvider(for key: String) -> StreamableProvider<ChainStorageItem>
}

final class SubstrateDataProviderFactory: SubstrateDataProviderFactoryProtocol {
    let facade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    init(facade: StorageFacadeProtocol,
         operationManager: OperationManagerProtocol,
         logger: LoggerProtocol? = nil) {
        self.facade = facade
        self.operationManager = operationManager
        self.logger = logger
    }

    func createStashItemProvider(for address: String) -> StreamableProvider<StashItem> {
        let mapper: CodableCoreDataMapper<StashItem, CDStashItem> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDStashItem.stash))

        let filter = NSPredicate.filterByStashOrController(address)
        let repository: CoreDataRepository<StashItem, CDStashItem> = facade
            .createRepository(filter: filter,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(mapper))

        let observable = CoreDataContextObservable(service: facade.databaseService,
                                                   mapper: AnyCoreDataMapper(mapper),
                                                   predicate: { $0.stash == address || $0.controller == address })

        observable.start { [weak self] (error) in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        return StreamableProvider<StashItem>(source: AnyStreamableSource(EmptyStreamableSource()),
                                             repository: AnyDataProviderRepository(repository),
                                             observable: AnyDataProviderRepositoryObservable(observable),
                                             operationManager: operationManager)
    }

    func createRuntimeMetadataItemProvider(for chain: Chain) -> StreamableProvider<RuntimeMetadataItem> {
        let identifier = chain.genesisHash

        let filter = NSPredicate.filterRuntimeMetadataItemsBy(identifier: identifier)
        let storage: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            facade.createRepository(filter: filter)
        let source = EmptyStreamableSource<RuntimeMetadataItem>()
        let observable = CoreDataContextObservable(service: facade.databaseService,
                                                   mapper: AnyCoreDataMapper(storage.dataMapper),
                                                   predicate: { $0.identifier == identifier })

        observable.start { error in
            if let error = error {
                self.logger?.error("Can't start storage observing: \(error)")
            }
        }

        return StreamableProvider(source: AnyStreamableSource(source),
                                  repository: AnyDataProviderRepository(storage),
                                  observable: AnyDataProviderRepositoryObservable(observable),
                                  operationManager: operationManager)
    }

    func createStorageProvider(for key: String) -> StreamableProvider<ChainStorageItem> {
        let filter = NSPredicate.filterStorageItemsBy(identifier: key)
        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            facade.createRepository(filter: filter)
        let source = EmptyStreamableSource<ChainStorageItem>()
        let observable = CoreDataContextObservable(service: facade.databaseService,
                                                   mapper: AnyCoreDataMapper(storage.dataMapper),
                                                   predicate: { $0.identifier == key })

        observable.start { error in
            if let error = error {
                self.logger?.error("Can't start storage observing: \(error)")
            }
        }

        return StreamableProvider(source: AnyStreamableSource(source),
                                  repository: AnyDataProviderRepository(storage),
                                  observable: AnyDataProviderRepositoryObservable(observable),
                                  operationManager: operationManager)
    }
}
