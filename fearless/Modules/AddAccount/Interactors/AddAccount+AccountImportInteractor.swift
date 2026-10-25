import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFUtils
import UIKit

extension AddAccount {
    final class AccountImportInteractor: BaseAccountImportInteractor {
        private(set) var settings: SelectedWalletSettings
        let eventCenter: EventCenterProtocol

        init(
            accountOperationFactory: MetaAccountOperationFactoryProtocol,
            accountRepository: AnyDataProviderRepository<MetaAccountModel>,
            operationManager: OperationManagerProtocol,
            settings: SelectedWalletSettings,
            keystoreImportService: KeystoreImportServiceProtocol,
            eventCenter: EventCenterProtocol,
            defaultSource: AccountImportSource
        ) {
            self.settings = settings
            self.eventCenter = eventCenter

            super.init(
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationManager: operationManager,
                keystoreImportService: keystoreImportService,
                defaultSource: defaultSource
            )
        }

        private func importAccountItem(_ item: MetaAccountModel, importOperation: BaseOperation<MetaAccountModel>) {
            let checkOperation = accountRepository.fetchOperation(
                by: item.identifier,
                options: RepositoryFetchOptions()
            )

            let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation {
                if try checkOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) != nil {
                    throw AccountCreateError.duplicated
                }

                return item
            }

            saveOperation.completionBlock = { [weak self] in
                let result = saveOperation.result
                saveOperation.completionBlock = nil
                DispatchQueue.main.async {
                    guard self != nil else {
                        ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
                        return
                    }
                    switch result {
                    case .success:
                        self?.settings.save(value: item, runningCompletionIn: .main) { result in
                            switch result {
                            case let .success(savedAccount):
                                (importOperation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
                                if self?.settings.value == savedAccount {
                                    self?.eventCenter.notify(with: SelectedAccountChanged(account: savedAccount))
                                }
                                self?.presenter?.completeAccountImport(
                                    selectionIsCurrent: self?.settings.value == savedAccount
                                )
                            case let .failure(error):
                                Self.finishImportFailure(error, importOperation: importOperation, presenter: self?.presenter)
                            }
                        }

                    case let .failure(error):
                        Self.finishImportFailure(error, importOperation: importOperation, presenter: self?.presenter)

                    case .none:
                        let error = BaseOperationError.parentOperationCancelled
                        Self.finishImportFailure(error, importOperation: importOperation, presenter: self?.presenter)
                    }
                }
            }

            saveOperation.addDependency(checkOperation)

            operationManager.enqueue(
                operations: [checkOperation, saveOperation],
                in: .transient
            )
        }

        private static func finishImportFailure(
            _ error: Error, importOperation: BaseOperation<MetaAccountModel>,
            presenter: AccountImportInteractorOutputProtocol?
        ) {
            do {
                try (importOperation as? PersistenceBoundKeychainOperation)?.rollbackKeychainChanges()
                presenter?.didReceiveAccountImport(error: error)
            } catch let rollbackError {
                Logger.shared.error("Import rollback failed: \(rollbackError.localizedDescription)")
                presenter?.didReceiveAccountImport(error: rollbackError)
            }
        }

        override func importAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
            importOperation.completionBlock = { [weak self] in
                let result = importOperation.result
                importOperation.completionBlock = nil
                DispatchQueue.main.async {
                    guard self != nil else {
                        ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
                        return
                    }
                    switch result {
                    case let .success(accountItem):
                        self?.importAccountItem(accountItem, importOperation: importOperation)
                    case let .failure(error):
                        self?.presenter?.didReceiveAccountImport(error: error)
                    case .none:
                        let error = BaseOperationError.parentOperationCancelled
                        self?.presenter?.didReceiveAccountImport(error: error)
                    }
                }
            }

            operationManager.enqueue(operations: [importOperation], in: .transient)
        }
    }
}
