import Foundation
import IrohaCrypto
import RobinHood

protocol AccountRepositoryFactoryProtocol {
    // TODO: remove
    func createManagedRepository() -> AnyDataProviderRepository<ManagedAccountItem>
    func createRepository() -> AnyDataProviderRepository<AccountItem>

    // TODO: remove
    func createAccountRepository(for networkType: SNAddressType) -> AnyDataProviderRepository<AccountItem>
}

final class AccountRepositoryFactory: AccountRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func createManagedRepository() -> AnyDataProviderRepository<ManagedAccountItem> {
        Self.createManagedRepository(for: storageFacade)
    }

    func createRepository() -> AnyDataProviderRepository<AccountItem> {
        Self.createRepository(for: storageFacade)
    }

    // TODO: remove
    func createAccountRepository(
        for _: SNAddressType
    ) -> AnyDataProviderRepository<AccountItem> {
        Self.createRepository(for: storageFacade)
    }
}

extension AccountRepositoryFactory {
    static func createManagedRepository(
        for storageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared
    ) -> AnyDataProviderRepository<ManagedAccountItem> {
        let mapper = ManagedAccountItemMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }

    static func createRepository(
        for storageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared
    ) -> AnyDataProviderRepository<AccountItem> {
        let mapper = CodableCoreDataMapper<AccountItem, CDMetaAccount>()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }
}
