import Foundation
import RobinHood

protocol SubstrateRepositoryFactoryProtocol {
    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem>
    func createStashItemRepository() -> AnyDataProviderRepository<StashItem>
}

final class SubstrateRepositoryFactory: SubstrateRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
    }

    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem> {
        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(repository)
    }

    func createStashItemRepository() -> AnyDataProviderRepository<StashItem> {
        let repository: CoreDataRepository<StashItem, CDStashItem> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(repository)
    }
}
