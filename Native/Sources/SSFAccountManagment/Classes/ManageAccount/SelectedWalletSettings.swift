import Foundation
import RobinHood
import SSFAccountManagmentStorage
import SSFModels
import SSFUtils

public final class SelectedWalletSettings: PersistentValueSettings<MetaAccountModel> {
    private let operationQueue: OperationQueue
    private let metaAccountMapper: AnyCoreDataMapper<MetaAccountModel, CDMetaAccount>
    private let managedAccountMapper: AnyCoreDataMapper<ManagedMetaAccountModel, CDMetaAccount>

    public init(
        storageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        metaAccountMapper _: any CoreDataMapperProtocol = MetaAccountMapper(),
        managedAccountMapper _: any CoreDataMapperProtocol = ManagedMetaAccountMapper()
    ) {
        self.operationQueue = operationQueue
        metaAccountMapper = AnyCoreDataMapper(MetaAccountMapper())
        managedAccountMapper = AnyCoreDataMapper(ManagedMetaAccountMapper())
        super.init(storageFacade: storageFacade)
    }

    override public func performSetup(completionClosure: @escaping (Result<
        MetaAccountModel?,
        Error
    >) -> Void) {
        let repository = storageFacade.createRepository(
            filter: NSPredicate.selectedMetaAccount(),
            sortDescriptors: [],
            mapper: metaAccountMapper
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

    override public func performSave(
        value: MetaAccountModel,
        completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        let repository = storageFacade.createRepository(mapper: managedAccountMapper)

        let options = RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
        let maybeCurrentAccountOperation = internalValue.map {
            repository.fetchOperation(by: $0.identifier, options: options)
        }

        let newAccountOperation = repository.fetchOperation(by: value.identifier, options: options)

        let saveOperation = repository.saveOperation({
            var accountsToSave: [ManagedMetaAccountModel] = []

            if let currentAccount = try maybeCurrentAccountOperation?
                .extractNoCancellableResultData()
            {
                accountsToSave.append(
                    ManagedMetaAccountModel(
                        info: currentAccount.info,
                        isSelected: false,
                        order: currentAccount.order
                    )
                )
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
