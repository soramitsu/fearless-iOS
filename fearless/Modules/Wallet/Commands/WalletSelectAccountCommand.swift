import Foundation
import CommonWallet
import RobinHood
import SoraFoundation
import SoraKeystore

final class WalletSelectAccountCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let repositoryFactory: AccountRepositoryFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private(set) var settings: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol

    private var repository: AnyDataProviderRepository<AccountItem>?

    init(repositoryFactory: AccountRepositoryFactoryProtocol,
         commandFactory: WalletCommandFactoryProtocol,
         settings: SettingsManagerProtocol,
         eventCenter: EventCenterProtocol,
         localizationManager: LocalizationManagerProtocol) {
        self.repositoryFactory = repositoryFactory
        self.commandFactory = commandFactory
        self.settings = settings
        self.eventCenter = eventCenter
        self.localizationManager = localizationManager
    }

    private func handleAccountsSelection(_ accounts: [AccountItem]) {
        let networkType = settings.selectedConnection.type
        let selectedAccount = settings.selectedAccount

        guard let picker = ModalPickerFactory.createPickerList(accounts,
                                                               selectedAccount: selectedAccount,
                                                               addressType: networkType,
                                                               delegate: self,
                                                               context: accounts as NSArray) else {
            return
        }

        guard let command = commandFactory?.preparePresentationCommand(for: picker) else {
            return
        }

        command.presentationStyle = .modal(inNavigation: false)

        try? command.execute()
    }

    private func handleError(_ error: Error) {
        self.repository = nil

        let locale = localizationManager.selectedLocale
        let content = (error as? ErrorContentConvertible)?.toErrorContent(for: locale)
            ?? CommonError.undefined.toErrorContent(for: locale)

        let alertController = UIAlertController(title: content.title,
                                                message: content.message,
                                                preferredStyle: .alert)

        let closeTitle = R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)
        let closeAction = UIAlertAction(title: closeTitle,
                                        style: .cancel,
                                        handler: nil)
        alertController.addAction(closeAction)

        try? commandFactory?.preparePresentationCommand(for: alertController).execute()
    }

    private func handleAccountFetch(result: Result<[AccountItem], Error>?) {
        switch result {
        case .success(let accounts):
            handleAccountsSelection(accounts)
        case .failure(let error):
            handleError(error)
        case .none:
            handleError(BaseOperationError.parentOperationCancelled)
        }
    }

    func execute() throws {
        guard repository == nil else {
            return
        }

        let networkType = settings.selectedConnection.type
        let repository = repositoryFactory.createAccountRepository(for: networkType)
        let fetchAllOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        self.repository = repository

        fetchAllOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleAccountFetch(result: fetchAllOperation.result)
            }
        }

        repositoryFactory.operationManager.enqueue(operations: [fetchAllOperation],
                                                   in: .transient)
    }
}

extension WalletSelectAccountCommand: ModalPickerViewControllerDelegate {
    func modalPickerDidCancel(context: AnyObject?) {
        repository = nil
    }

    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        repository = nil

        guard let accounts = context as? NSArray,
            let account = accounts.object(at: index) as? AccountItem else {
            return
        }

        if account != settings.selectedAccount {
            settings.selectedAccount = account
            eventCenter.notify(with: SelectedAccountChanged())
        }
    }

    func modalPickerDidSelectAction(context: AnyObject?) {
        repository = nil

        guard
            let accountView = OnboardingMainViewFactory.createViewForAdding() else {
            return
        }

        guard let command = commandFactory?.preparePresentationCommand(for: accountView.controller) else {
            return
        }

        command.presentationStyle = .push(hidesBottomBar: true)

        try? command.execute()
    }
}
