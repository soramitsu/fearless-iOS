import Foundation
import SoraFoundation
import SSFCloudStorage

protocol BackupSelectWalletViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {
    func didReceive(viewModels: [String])
}

protocol BackupSelectWalletInteractorInput: AnyObject {
    func setup(with output: BackupSelectWalletInteractorOutput)
}

final class BackupSelectWalletPresenter {
    // MARK: Private properties

    private weak var view: BackupSelectWalletViewInput?
    private let router: BackupSelectWalletRouterInput
    private let interactor: BackupSelectWalletInteractorInput

    private let accounts: [OpenBackupAccount]

    // MARK: - Constructors

    init(
        accounts: [OpenBackupAccount],
        interactor: BackupSelectWalletInteractorInput,
        router: BackupSelectWalletRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.accounts = accounts
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModels() {
        let names = accounts.map { $0.name ?? $0.address }
        view?.didReceive(viewModels: names)
    }
}

// MARK: - BackupSelectWalletViewOutput

struct BackupAccount {
    let account: OpenBackupAccount
    let current: Bool
}

extension BackupSelectWalletPresenter: BackupSelectWalletViewOutput {
    func didLoad(view: BackupSelectWalletViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModels()
    }

    func didTap(on indexPath: IndexPath) {
        let backupAccounts = accounts.enumerated().map {
            BackupAccount(
                account: $0.1,
                current: indexPath.row == $0.0
            )
        }
        router.presentBackupPasswordScreen(for: backupAccounts, from: view)
    }

    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didCreateNewAccountButtonTapped() {}
}

// MARK: - BackupSelectWalletInteractorOutput

extension BackupSelectWalletPresenter: BackupSelectWalletInteractorOutput {}

// MARK: - Localizable

extension BackupSelectWalletPresenter: Localizable {
    func applyLocalization() {}
}

extension BackupSelectWalletPresenter: BackupSelectWalletModuleInput {}

protocol BackupSelectWalletViewModelFactoryProtocol {}

final class BackupSelectWalletViewModelFactory: BackupSelectWalletViewModelFactoryProtocol {}
