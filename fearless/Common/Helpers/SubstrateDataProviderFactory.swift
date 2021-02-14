import Foundation
import RobinHood

protocol SubstrateDataProviderFactoryProtocol {
    func createRuntimeMetadataItemProvider(for chain: Chain) -> StreamableProvider<RuntimeMetadataItem>
}

final class SubstrateDataProviderFactory: SubstrateDataProviderFactoryProtocol {
    let facade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol

    init(facade: StorageFacadeProtocol, operationManager: OperationManagerProtocol) {
        self.facade = facade
        self.operationManager = operationManager
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

        let operationManager = OperationManagerFacade.sharedManager

        return StreamableProvider(source: AnyStreamableSource(source),
                                  repository: AnyDataProviderRepository(storage),
                                  observable: AnyDataProviderRepositoryObservable(observable),
                                  operationManager: operationManager)
    }
}
