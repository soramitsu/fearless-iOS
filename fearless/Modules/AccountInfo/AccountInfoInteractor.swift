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

    init(repository: AnyDataProviderRepository<ManagedAccountItem>,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         eventCenter: EventCenterProtocol,
         operationManager: OperationManagerProtocol) {
        self.repository = repository
        self.settings = settings
        self.keystore = keystore
        self.eventCenter = eventCenter
        self.operationManager = operationManager
    }

    private func handleUsernameSave(result: Result<Void, Error>?,
                                    username: String,
                                    accountId: String) {
        guard let result = result else {
            presenter.didReceive(error: BaseOperationError.parentOperationCancelled)
            return
        }

        switch result {
        case .success:
            if
                let selectedAccount = settings.selectedAccount, selectedAccount.identifier == accountId {
                let newSelectedAccount = selectedAccount.replacingUsername(username)
                settings.selectedAccount = newSelectedAccount
                eventCenter.notify(with: SelectedAccountChanged())
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
}

extension AccountInfoInteractor: AccountInfoInteractorInputProtocol {
    func setup(accountId: String) {
        let operation = repository.fetchOperation(by: accountId, options: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleAccountItem(result: operation.result)
            }
        }

        operationManager.enqueue(operations: [operation], in: .sync)
    }

    func save(username: String, accountId: String) {
        let fetchOperation = repository.fetchOperation(by: accountId, options: RepositoryFetchOptions())
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
                                         accountId: accountId)
            }
        }

        operationManager.enqueue(operations: [fetchOperation, saveOperation], in: .sync)
    }

    func requestExportOptions(accountId: String) {
        do {
            var options: [ExportOption] = [.keystore]

            if try keystore.checkEntropyForAddress(accountId) {
                options.insert(.mnemonic, at: 0)
            }

            presenter.didReceive(exportOptions: options)
        } catch {
            presenter.didReceive(error: error)
        }
    }
}
