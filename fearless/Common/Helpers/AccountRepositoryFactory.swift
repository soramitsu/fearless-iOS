import Foundation
import IrohaCrypto
import RobinHood

protocol AccountRepositoryFactoryProtocol {
    var operationManager: OperationManagerProtocol { get }

    // TODO: remove
    func createManagedRepository() -> AnyDataProviderRepository<ManagedAccountItem>
    func createRepository() -> AnyDataProviderRepository<AccountItem>

    // TODO: remove
    func createAccountRepository(for networkType: SNAddressType)
        -> AnyDataProviderRepository<AccountItem>
    func createStreambleProvider(for accountAddress: AccountAddress) -> StreamableProvider<AccountItem>
}

final class AccountRepositoryFactory: AccountRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    init(
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.logger = logger
    }

    func createManagedRepository() -> AnyDataProviderRepository<ManagedAccountItem> {
        let mapper = ManagedAccountItemMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }

    func createRepository() -> AnyDataProviderRepository<AccountItem> {
        let mapper = CodableCoreDataMapper<AccountItem, CDMetaAccount>()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }

    // TODO: remove
    func createAccountRepository(
        for _: SNAddressType
    ) -> AnyDataProviderRepository<AccountItem> {
        createRepository()
    }

    func createStreambleProvider(for accountAddress: AccountAddress) -> StreamableProvider<AccountItem> {
        let mapper: CodableCoreDataMapper<AccountItem, CDMetaAccount> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDMetaAccount.metaId))

        let filter = NSPredicate.filterAccountItemByAddress(accountAddress)
        let repository: CoreDataRepository<AccountItem, CDMetaAccount> = storageFacade
            .createRepository(
                filter: filter,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        // TODO: fix filtering by account id
        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { $0.metaId == accountAddress }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        return StreamableProvider<AccountItem>(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )
    }
}
