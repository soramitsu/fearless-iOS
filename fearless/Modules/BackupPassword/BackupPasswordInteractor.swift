import RobinHood
import SSFCloudStorage
import UIKit

protocol BackupPasswordInteractorOutput: AnyObject {
    func didReceiveBackup(result: Result<OpenBackupAccount, Error>)
    func didReceiveAccountImport(error: Error)
    func didCompleteAccountImport()
    func showGoogleIssueError()
}

final class BackupPasswordInteractor: BaseAccountImportInteractor {
    var cloudStorage: CloudStorageServiceProtocol?

    // MARK: - Private properties

    private weak var output: BackupPasswordInteractorOutput?

    private let settings: SelectedWalletSettings
    private let eventCenter: EventCenterProtocol

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

    override func importAccountUsingOperation(_ importOperation: BaseOperation<MetaAccountModel>) {
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation {
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            return accountItem.replacingIsBackuped(true)
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
                        switch result {
                        case let .success(savedAccount):
                            (importOperation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
                            self?.output?.didCompleteAccountImport()
                            self?.eventCenter.notify(with: SelectedAccountChanged(account: savedAccount))
                        case let .failure(error):
                            let failure = ImportKeychainPersistence.rollback(importOperation, after: error)
                            self?.output?.didReceiveAccountImport(error: failure)
                        }
                    }
                case let .failure(error):
                    let failure = ImportKeychainPersistence.rollback(importOperation, after: error)
                    self.output?.didReceiveAccountImport(error: failure)
                case .none:
                    let failure = ImportKeychainPersistence.rollback(importOperation, after: BaseOperationError.parentOperationCancelled)
                    self.output?.didReceiveAccountImport(error: failure)
                }
            }
        }

        saveOperation.addDependency(importOperation)

        operationManager.enqueue(
            operations: [importOperation, saveOperation],
            in: .transient
        )
    }

    private func handle(error: Error) {
        if let error = error as? CloudStorageServiceError {
            switch error {
            case .notAuthorized:
                cloudStorage?.disconnect()
                DispatchQueue.main.async {
                    self.output?.showGoogleIssueError()
                }
            case .incorectPassword, .incorectJson, .notFound, .readbackMismatch:
                DispatchQueue.main.async {
                    self.output?.didReceiveBackup(result: .failure(error))
                }
            }
            return
        } else {
            cloudStorage?.disconnect()
            DispatchQueue.main.async {
                self.output?.showGoogleIssueError()
            }
        }
    }
}

// MARK: - BackupPasswordInteractorInput

extension BackupPasswordInteractor: BackupPasswordInteractorInput {
    func setup(with output: BackupPasswordInteractorOutput) {
        self.output = output
    }

    func importBackup(account: OpenBackupAccount, password: String) {
        Task {
            do {
                if let cloudStorage = cloudStorage {
                    let account = try await cloudStorage.importBackup(account: account, password: password)
                    await MainActor.run {
                        output?.didReceiveBackup(result: .success(account))
                    }
                }
            } catch {
                handle(error: error)
            }
        }
    }

    func signInIfNeeded() {
        Task {
            try await cloudStorage?.signInIfNeeded()
        }
    }
}
