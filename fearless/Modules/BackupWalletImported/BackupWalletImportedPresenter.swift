import Foundation
import SoraFoundation

protocol BackupWalletImportedViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {
    func didReceive(viewModel: BackupWalletImportedViewModel)
}

protocol BackupWalletImportedInteractorInput: AnyObject {
    func setup(with output: BackupWalletImportedInteractorOutput)
}

struct BackupWalletImportedViewModel {
    let walletName: String
    let importMoreButtomIsHidden: Bool
}

final class BackupWalletImportedPresenter {
    // MARK: Private properties

    private weak var view: BackupWalletImportedViewInput?
    private let router: BackupWalletImportedRouterInput
    private let interactor: BackupWalletImportedInteractorInput

    private let backupAccounts: [BackupAccount]

    // MARK: - Constructors

    init(
        backupAccounts: [BackupAccount],
        interactor: BackupWalletImportedInteractorInput,
        router: BackupWalletImportedRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.backupAccounts = backupAccounts
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let importMoreButtomIsHidden = backupAccounts.filter { $0.current == false }.count == 0
        guard let current = backupAccounts.first(where: { $0.current })?.account else {
            return
        }
        let viewModel = BackupWalletImportedViewModel(
            walletName: current.name ?? current.address,
            importMoreButtomIsHidden: importMoreButtomIsHidden
        )
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - BackupWalletImportedViewOutput

extension BackupWalletImportedPresenter: BackupWalletImportedViewOutput {
    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didContinueButtonTapped() {
        router.showSetupPin(from: view)
    }

    func didImportMoreButtonTapped() {
        let backupAccount = backupAccounts.filter { $0.current == false }.map { $0.account }
        router.showBackupSelectWallet(for: backupAccount, from: view)
    }

    func didLoad(view: BackupWalletImportedViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }
}

// MARK: - BackupWalletImportedInteractorOutput

extension BackupWalletImportedPresenter: BackupWalletImportedInteractorOutput {}

// MARK: - Localizable

extension BackupWalletImportedPresenter: Localizable {
    func applyLocalization() {}
}

extension BackupWalletImportedPresenter: BackupWalletImportedModuleInput {}
