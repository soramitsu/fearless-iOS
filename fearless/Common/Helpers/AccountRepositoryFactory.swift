import Foundation
import IrohaCrypto
import RobinHood

protocol AccountRepositoryFactoryProtocol {
    var operationManager: OperationManagerProtocol { get }

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

    func createAccountRepository(
        for networkType: SNAddressType
    ) -> AnyDataProviderRepository<AccountItem> {
        let mapper = CodableCoreDataMapper<AccountItem, CDAccountItem>()
        let repository = storageFacade
            .createRepository(
                filter: NSPredicate.filterAccountBy(networkType: networkType),
                sortDescriptors: [NSSortDescriptor.accountsByOrder],
                mapper: AnyCoreDataMapper(mapper)
            )

        return AnyDataProviderRepository(repository)
    }

    func createStreambleProvider(for accountAddress: AccountAddress) -> StreamableProvider<AccountItem> {
        let mapper: CodableCoreDataMapper<AccountItem, CDAccountItem> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDAccountItem.identifier))

        let filter = NSPredicate.filterAccountItemByAddress(accountAddress)
        let repository: CoreDataRepository<AccountItem, CDAccountItem> = storageFacade
            .createRepository(
                filter: filter,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { $0.identifier == accountAddress }
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
