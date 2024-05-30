import Foundation
import IrohaCrypto
import RobinHood

protocol AccountRepositoryFactoryProtocol {
    // TODO: remove
    @available(*, deprecated, message: "Use createMetaAccountRepository(for filter:, sortDescriptors:) instead")
    func createRepository() -> AnyDataProviderRepository<MetaAccountModel>

    // TODO: remove
    func createAccountRepository(for networkType: SNAddressType) -> AnyDataProviderRepository<MetaAccountModel>

    func createMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<MetaAccountModel>

    func createManagedMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<ManagedMetaAccountModel>

    func createAsyncMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AsyncAnyRepository<MetaAccountModel>
}

final class AccountRepositoryFactory: AccountRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func createRepository() -> AnyDataProviderRepository<MetaAccountModel> {
        Self.createRepository(for: storageFacade)
    }

    // TODO: remove
    func createAccountRepository(
        for _: SNAddressType
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        Self.createRepository(for: storageFacade)
    }

    func createMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        let mapper = MetaAccountMapper()

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    func createManagedMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<ManagedMetaAccountModel> {
        let mapper = ManagedMetaAccountMapper()

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    func createAsyncMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AsyncAnyRepository<MetaAccountModel> {
        let mapper = MetaAccountMapper()
        let repository = storageFacade.createAsyncRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )
        return AsyncAnyRepository(repository)
    }
}

extension AccountRepositoryFactory {
    static func createRepository(
        for storageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        let mapper = MetaAccountMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }
}
