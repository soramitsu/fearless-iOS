import UIKit
import RobinHood
import SSFCloudStorage

protocol BackupPasswordInteractorOutput: AnyObject {
    func didReceiveBackup(result: Result<OpenBackupAccount, Error>)
    func didReceiveAccountImport(error: Error)
    func didCompleteAccountImport()
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
        let saveOperation: ClosureOperation<MetaAccountModel> = ClosureOperation { [weak self] in
            let accountItem = try importOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let updatedWallet = accountItem.replacingIsBackuped(true)
            self?.settings.save(value: updatedWallet)

            return updatedWallet
        }

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    self?.settings.setup()
                    self?.output?.didCompleteAccountImport()
                    self?.eventCenter.notify(with: SelectedAccountChanged())

                case let .failure(error):
                    self?.output?.didReceiveAccountImport(error: error)

                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.output?.didReceiveAccountImport(error: error)
                }
            }
        }

        saveOperation.addDependency(importOperation)

        operationManager.enqueue(
            operations: [importOperation, saveOperation],
            in: .transient
        )
    }
}

// MARK: - BackupPasswordInteractorInput

extension BackupPasswordInteractor: BackupPasswordInteractorInput {
    func setup(with output: BackupPasswordInteractorOutput) {
        self.output = output
    }

    func importBackup(account: OpenBackupAccount, password: String) {
        cloudStorage?.importBackupAccount(account: account, password: password) { [weak self] result in
            self?.output?.didReceiveBackup(result: result)
        }
    }
}
