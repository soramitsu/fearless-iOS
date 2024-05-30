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
        let maybeCurrentAccountOperation = internalValue.map {
            repository.fetchOperation(by: $0.identifier, options: options)
        }

        let newAccountOperation = repository.fetchOperation(by: value.identifier, options: options)

        let saveOperation = repository.saveOperation({
            var accountsToSave: [ManagedMetaAccountModel] = []

            if let currentAccount = try maybeCurrentAccountOperation?.extractNoCancellableResultData() {
                let newAccount = try? newAccountOperation.extractNoCancellableResultData()
                if currentAccount.identifier != newAccount?.identifier {
                    accountsToSave.append(
                        ManagedMetaAccountModel(
                            info: currentAccount.info,
                            isSelected: false,
                            order: currentAccount.order
                        )
                    )
                }
            }

            if let newAccount = try newAccountOperation.extractNoCancellableResultData() {
                accountsToSave.append(
                    ManagedMetaAccountModel(
                        info: value,
                        isSelected: true,
                        order: newAccount.order
                    )
                )
            } else {
                accountsToSave.append(
                    ManagedMetaAccountModel(info: value, isSelected: true)
                )
            }

            return accountsToSave
        }, { [] })

        var dependencies: [Operation] = [newAccountOperation]

        if let currentAccountOperation = maybeCurrentAccountOperation {
            dependencies.append(currentAccountOperation)
        }

        dependencies.forEach { saveOperation.addDependency($0) }

        saveOperation.completionBlock = { [weak self] in
            do {
                _ = try saveOperation.extractNoCancellableResultData()
                self?.internalValue = value
                completionClosure(.success(value))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations(dependencies + [saveOperation], waitUntilFinished: false)
    }
}
