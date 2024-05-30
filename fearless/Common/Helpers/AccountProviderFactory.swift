import Foundation
import IrohaCrypto
import RobinHood
import SSFAccountManagmentStorage

protocol AccountProviderFactoryProtocol {
    var operationManager: OperationManagerProtocol { get }

    func createStreambleProvider(
        for accountId: AccountId
    ) -> StreamableProvider<MetaAccountModel>
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

    func createStreambleProvider(
        for accountId: AccountId
    ) -> StreamableProvider<MetaAccountModel> {
        let mapper = MetaAccountMapper()

        let filter = NSPredicate.filterAccountItemByAccountId(accountId)
        let repository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = storageFacade
            .createRepository(
                filter: filter,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let hexAccountId = accountId.toHex()
        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { metaAccount in
                metaAccount.substrateAccountId == hexAccountId ||
                    metaAccount.ethereumAddress == hexAccountId ||
                    metaAccount.chainAccounts?.contains(
                        where: { chainEntity in
                            guard let chainAccount = chainEntity as? CDChainAccount else {
                                return false
                            }

                            return chainAccount.accountId == hexAccountId
                        }
                    ) ?? false
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        return StreamableProvider<MetaAccountModel>(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )
    }
}
