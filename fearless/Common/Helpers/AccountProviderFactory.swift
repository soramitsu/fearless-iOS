import Foundation
import IrohaCrypto
import RobinHood

protocol AccountProviderFactoryProtocol {
    var operationManager: OperationManagerProtocol { get }

    func createStreambleProvider(for accountAddress: AccountAddress) -> StreamableProvider<AccountItem>
}

final class AccountProviderFactory: AccountProviderFactoryProtocol {
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
