import Foundation
import IrohaCrypto
import RobinHood

protocol AccountRepositoryFactoryProtocol {
    var operationManager: OperationManagerProtocol { get }

    func createAccountRepsitory(for networkType: SNAddressType)
        -> AnyDataProviderRepository<AccountItem>
}

final class AccountRepositoryFactory: AccountRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol

    init(storageFacade: StorageFacadeProtocol, operationManager: OperationManagerProtocol) {
        self.storageFacade = storageFacade
        self.operationManager = operationManager
    }

    func createAccountRepsitory(for networkType: SNAddressType)
        -> AnyDataProviderRepository<AccountItem> {
            let mapper = CodableCoreDataMapper<AccountItem, CDAccountItem>()
            let repository = storageFacade
                .createRepository(filter: NSPredicate.filterBy(networkType: networkType),
                                  sortDescriptors: [NSSortDescriptor.accountsByOrder],
                                  mapper: AnyCoreDataMapper(mapper))

            return AnyDataProviderRepository(repository)
    }
}
