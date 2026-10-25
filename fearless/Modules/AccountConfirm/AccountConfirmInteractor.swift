import IrohaCrypto
import RobinHood
import SoraKeystore
import UIKit

class AccountConfirmInteractor: BaseAccountConfirmInteractor {
    private(set) var settings: SelectedWalletSettings
    private var currentOperation: Operation?

    let eventCenter: EventCenterProtocol

    init(
        flow: AccountConfirmFlow,
        accountOperationFactory: MetaAccountOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        settings: SelectedWalletSettings,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.eventCenter = eventCenter

        super.init(
            flow: flow,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: operationManager
        )
    }

    override func createAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        guard currentOperation == nil else {
            return
        }

        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation {
            try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        }

        saveOperation.completionBlock = { [weak self] in
            let result = saveOperation.result
            saveOperation.completionBlock = nil
            DispatchQueue.main.async {
                guard let self else {
                    ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
                    return
                }
                switch result {
                case let .success(accountItem):
                    self.settings.save(value: accountItem, runningCompletionIn: .main) { [weak self] result in
                        self?.currentOperation = nil
                        switch result {
                        case let .success(savedAccount):
                            (importOperation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
                            self?.eventCenter.notify(with: SelectedAccountChanged(account: savedAccount))
                            self?.presenter?.didCompleteConfirmation()
                        case let .failure(error):
                            let failure = ImportKeychainPersistence.rollback(importOperation, after: error)
                            self?.presenter?.didReceive(error: failure)
                        }
                    }
                case let .failure(error):
                    self.currentOperation = nil
                    let failure = ImportKeychainPersistence.rollback(importOperation, after: error)
                    self.presenter?.didReceive(error: failure)
                case .none:
                    self.currentOperation = nil
                    let failure = ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
                    self.presenter?.didReceive(error: failure)
                }
            }
        }

        saveOperation.addDependency(importOperation)
        currentOperation = saveOperation

        operationManager.enqueue(
            operations: [importOperation, saveOperation],
            in: .transient
        )
    }
}
