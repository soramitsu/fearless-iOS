import Foundation
import RobinHood

final class SelectedWalletSettings: PersistentValueSettings<MetaAccountModel> {
    static let shared = SelectedWalletSettings(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.persistentQueue
    )

    let operationQueue: OperationQueue
    let mapper = ManagedMetaAccountMapper()
    lazy var repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

    init(storageFacade: StorageFacadeProtocol, operationQueue: OperationQueue) {
        self.operationQueue = operationQueue

        super.init(storageFacade: storageFacade)
    }

    override func performSetup(completionClosure: @escaping (Result<MetaAccountModel?, Error>) -> Void) {
        let mapper = MetaAccountMapper()
        let repository = storageFacade.createRepository(
            filter: NSPredicate.selectedMetaAccount(),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let operation = repository.fetchAllOperation(with: options)

        operation.completionBlock = {
            do {
                let result = try operation.extractNoCancellableResultData().first
                completionClosure(.success(result))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperation(operation)
    }

    override func performSave(
        value: MetaAccountModel,
        completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let allAccountsOperation = repository.fetchAllOperation(with: options)

        let saveOperation = repository.saveOperation({
            let existingAccounts = try allAccountsOperation.extractNoCancellableResultData()

            var accountsById = existingAccounts.reduce(into: [String: ManagedMetaAccountModel]()) { result, account in
                result[account.identifier] = account
            }

            if let currentAccount = existingAccounts.first(where: \.isSelected),
               currentAccount.identifier != value.identifier {
                accountsById[currentAccount.identifier] = ManagedMetaAccountModel(
                    info: currentAccount.info,
                    isSelected: false,
                    order: currentAccount.order
                )
            }

            if let existingAccount = accountsById[value.identifier] {
                accountsById[value.identifier] = ManagedMetaAccountModel(
                    info: value,
                    isSelected: true,
                    order: existingAccount.order
                )
            } else {
                accountsById[value.identifier] = ManagedMetaAccountModel(
                    info: value,
                    isSelected: true
                )
            }

            return Array(accountsById.values)
        }, { [] })

        saveOperation.addDependency(allAccountsOperation)

        saveOperation.completionBlock = { [weak self] in
            do {
                _ = try saveOperation.extractNoCancellableResultData()
                self?.internalValue = value
                completionClosure(.success(value))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations([allAccountsOperation, saveOperation], waitUntilFinished: false)
    }
}
