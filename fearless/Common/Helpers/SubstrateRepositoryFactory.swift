import Foundation
import RobinHood
import SSFSingleValueCache
import SSFAccountManagmentStorage

protocol SubstrateRepositoryFactoryProtocol {
    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem>
    func createStashItemRepository() -> AnyDataProviderRepository<StashItem>
    func createSingleValueRepository() throws -> AnyDataProviderRepository<SingleValueProviderObject>
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

    func createAccountInfoStorageItemRepository() -> AnyDataProviderRepository<AccountInfoStorageWrapper> {
        let repository: CoreDataRepository<AccountInfoStorageWrapper, CDAccountInfo> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(repository)
    }

    func createStashItemRepository() -> AnyDataProviderRepository<StashItem> {
        let mapper: CodableCoreDataMapper<StashItem, CDStashItem> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDStashItem.stash))

        let repository: CoreDataRepository<StashItem, CDStashItem> =
            storageFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        return AnyDataProviderRepository(repository)
    }

    func createSingleValueRepository() throws -> AnyDataProviderRepository<SingleValueProviderObject> {
        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = try SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()
        return AnyDataProviderRepository(repository)
    }
}
