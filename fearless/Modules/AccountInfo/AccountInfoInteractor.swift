import UIKit
import RobinHood
import SoraKeystore

enum AccountInfoInteractorError: Error {
    case missingAccount
}

final class AccountInfoInteractor {
    weak var presenter: AccountInfoInteractorOutputProtocol!

    let repository: AnyDataProviderRepository<ManagedAccountItem>
    private(set) var settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    let keystore: KeystoreProtocol
    let operationManager: OperationManagerProtocol

    private lazy var usernameSaveScheduler = Scheduler(with: self, callbackQueue: .main)
    private var saveUsernameInterval: TimeInterval
    private var pendingUsername: String?
    private var pendingAddress: String?

    init(repository: AnyDataProviderRepository<ManagedAccountItem>,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         eventCenter: EventCenterProtocol,
         operationManager: OperationManagerProtocol,
         saveUsernameInterval: TimeInterval = 2.0) {
        self.repository = repository
        self.settings = settings
        self.keystore = keystore
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.saveUsernameInterval = saveUsernameInterval
    }

    private func handleUsernameSave(result: Result<Void, Error>?,
                                    username: String,
                                    address: String) {
        guard let result = result else {
            presenter.didReceive(error: BaseOperationError.parentOperationCancelled)
            return
        }

        switch result {
        case .success:
            if
                let selectedAccount = settings.selectedAccount, selectedAccount.address == address {
                let newSelectedAccount = selectedAccount.replacingUsername(username)
                settings.selectedAccount = newSelectedAccount
                eventCenter.notify(with: SelectedUsernameChanged())
            }

            presenter.didSave(username: username)
        case .failure(let error):
            presenter.didReceive(error: error)
        }
    }

    private func handleAccountItem(result: Result<ManagedAccountItem?, Error>?) {
        guard let result = result else {
            presenter.didReceive(error: BaseOperationError.parentOperationCancelled)
            return
        }

        switch result {
        case .success(let accountItem):
            if let accountItem = accountItem {
                presenter.didReceive(accountItem: accountItem)
            } else {
                presenter.didReceive(error: AccountInfoInteractorError.missingAccount)
            }
        case .failure(let error):
            presenter.didReceive(error: error)
        }
    }

    private func performUsernameSave(_ username: String, address: String) {
        let fetchOperation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())
        let saveOperation = repository.saveOperation({
            guard let changingAccountItem = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw AccountInfoInteractorError.missingAccount
            }

            guard changingAccountItem.username != username else {
                return []
            }

            let newAccountItem = changingAccountItem.replacingUsername(username)

            return [newAccountItem]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleUsernameSave(result: saveOperation.result,
                                         username: username,
                                         address: address)
            }
        }

        operationManager.enqueue(operations: [fetchOperation, saveOperation], in: .sync)
    }

    private func performUsernameFinalizationIfNeeded() {
        if let username = pendingUsername, let address = pendingAddress {
            pendingUsername = nil
            pendingAddress = nil

            performUsernameSave(username, address: address)
        }
    }
}

extension AccountInfoInteractor: AccountInfoInteractorInputProtocol {
    func setup(address: String) {
        let operation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())

        operation.completionBlock = {
            DispatchQueue.main.async {
                self.handleAccountItem(result: operation.result)
            }
        }

        operationManager.enqueue(operations: [operation], in: .sync)
    }

    func save(username: String, address: String) {
        let shouldScheduleSave = pendingUsername == nil

        pendingUsername = username
        pendingAddress = address

        if shouldScheduleSave {
            usernameSaveScheduler.notifyAfter(saveUsernameInterval)
        }
    }

    func flushPendingUsername() {
        performUsernameFinalizationIfNeeded()
    }

    func requestExportOptions(accountItem: ManagedAccountItem) {
        do {
            var options: [ExportOption] = [.keystore]

            if try keystore.checkEntropyForAddress(accountItem.address) {
                options.append(.mnemonic)
            }

            let hasSeed = try keystore.checkSeedForAddress(accountItem.address)
            if hasSeed || accountItem.cryptoType.supportsSeedFromSecretKey {
                options.append(.seed)
            }

            presenter.didReceive(exportOptions: options)
        } catch {
            presenter.didReceive(error: error)
        }
    }
}

extension AccountInfoInteractor: SchedulerDelegate {
    func didTrigger(scheduler: SchedulerProtocol) {
        performUsernameFinalizationIfNeeded()
    }
}
