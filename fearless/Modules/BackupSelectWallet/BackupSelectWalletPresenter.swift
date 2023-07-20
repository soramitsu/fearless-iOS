import Foundation
import SoraFoundation
import SSFCloudStorage

protocol BackupSelectWalletViewInput: ControllerBackedProtocol, HiddableBarWhenPushed, LoadableViewProtocol {
    func didReceive(viewModels: [String])
}

protocol BackupSelectWalletInteractorInput: AnyObject {
    func setup(with output: BackupSelectWalletInteractorOutput)
    func fetchBackupAccounts()
}

final class BackupSelectWalletPresenter {
    // MARK: Private properties

    private weak var view: BackupSelectWalletViewInput?
    private let router: BackupSelectWalletRouterInput
    private let interactor: BackupSelectWalletInteractorInput

    private var accounts: [OpenBackupAccount]?
    private var backupedAddresses: [String]?

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
        let filtredAccounts = accounts.filter { !backupedAddresses.or([]).contains($0.address) }
        let names = filtredAccounts.map { $0.name ?? $0.address }
        DispatchQueue.main.async {
            self.view?.didReceive(viewModels: names)
        }
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
}

// MARK: - BackupSelectWalletInteractorOutput

extension BackupSelectWalletPresenter: BackupSelectWalletInteractorOutput {
    func didReceiveWallets(result: Result<[ManagedMetaAccountModel], Error>) {
        switch result {
        case let .success(wallets):
            backupedAddresses = wallets.map { $0.info.substrateAccountId.toHex() }
            provideViewModels()
        case .failure:
            break
        }
    }

    func didReceiveBackupAccounts(result: Result<[SSFCloudStorage.OpenBackupAccount], Error>) {
        view?.didStopLoading()
        switch result {
        case let .success(accounts):
            self.accounts = accounts
            provideViewModels()
        case let .failure(failure):
            let error = ConvenienceError(error: failure.localizedDescription)
            DispatchQueue.main.async {
                self.router.present(error: error, from: self.view, locale: self.selectedLocale)
            }
        }
    }
}

// MARK: - Localizable

extension BackupSelectWalletPresenter: Localizable {
    func applyLocalization() {}
}

extension BackupSelectWalletPresenter: BackupSelectWalletModuleInput {}
