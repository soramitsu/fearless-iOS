import Foundation
import SoraFoundation
import SSFCloudStorage

protocol BackupSelectWalletViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol {
    func didReceive(viewModels: [String])
}

protocol BackupSelectWalletInteractorInput: AnyObject {
    func setup(with output: BackupSelectWalletInteractorOutput)
    func fetchBackupAccounts()
    func disconnect()
}

final class BackupSelectWalletPresenter {
    // MARK: Private properties

    private weak var view: BackupSelectWalletViewInput?
    private let router: BackupSelectWalletRouterInput
    private let interactor: BackupSelectWalletInteractorInput

    private var accounts: [OpenBackupAccount]?

    // MARK: - Constructors

    init(
        accounts: [OpenBackupAccount]?,
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
        guard let accounts = accounts else {
            interactor.fetchBackupAccounts()
            return
        }
        let names = accounts.compactMap { $0.name }
        view?.didReceive(viewModels: names)
    }

    private func showGoogleIssueAlert() {
        let title = R.string.localizable
            .noAccessToGoogle(preferredLanguages: selectedLocale.rLanguages)
        let retryTitle = R.string.localizable
            .tryAgain(preferredLanguages: selectedLocale.rLanguages)
        let retryAction = SheetAlertPresentableAction(
            title: retryTitle,
            style: .pinkBackgroundWhiteText,
            button: UIFactory.default.createMainActionButton()
        ) { [weak self] in
            self?.interactor.fetchBackupAccounts()
        }
        router.present(
            message: nil,
            title: title,
            closeAction: nil,
            from: view,
            actions: [retryAction]
        )
    }
}

// MARK: - BackupSelectWalletViewOutput

struct BackupAccount {
    let account: OpenBackupAccount
    let current: Bool
}

extension BackupSelectWalletPresenter: BackupSelectWalletViewOutput {
    func viewDidAppear() {
        if accounts == nil {
            view?.didStartLoading()
            provideViewModels()
        }
    }

    func didLoad(view: BackupSelectWalletViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModels()
    }

    func didTap(on indexPath: IndexPath) {
        guard let accounts = accounts else {
            return
        }
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

    func didCreateNewAccountButtonTapped() {
        router.showWalletNameScreen(from: view)
    }

    func beingDismissed() {
        interactor.disconnect()
    }
}

// MARK: - BackupSelectWalletInteractorOutput

extension BackupSelectWalletPresenter: BackupSelectWalletInteractorOutput {
    func didReceiveBackupAccounts(result: Result<[SSFCloudStorage.OpenBackupAccount], Error>) {
        view?.didStopLoading()
        switch result {
        case let .success(accounts):
            self.accounts = accounts
            provideViewModels()
        case .failure:
            showGoogleIssueAlert()
        }
    }
}

// MARK: - Localizable

extension BackupSelectWalletPresenter: Localizable {
    func applyLocalization() {}
}

extension BackupSelectWalletPresenter: BackupSelectWalletModuleInput {}
