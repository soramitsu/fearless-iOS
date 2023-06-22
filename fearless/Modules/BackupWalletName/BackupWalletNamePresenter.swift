import Foundation
import SoraFoundation

protocol BackupWalletNameViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {}

protocol BackupWalletNameInteractorInput: AnyObject {
    func setup(with output: BackupWalletNameInteractorOutput)
}

final class BackupWalletNamePresenter {
    // MARK: Private properties

    private weak var view: BackupWalletNameViewInput?
    private let router: BackupWalletNameRouterInput
    private let interactor: BackupWalletNameInteractorInput

    private var walletName: String?

    // MARK: - Constructors

    init(
        interactor: BackupWalletNameInteractorInput,
        router: BackupWalletNameRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - BackupWalletNameViewOutput

extension BackupWalletNamePresenter: BackupWalletNameViewOutput {
    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didContinueButtonTapped() {
        guard let walletName = walletName else {
            return
        }
        router.showWarningsScreen(walletName: walletName, from: view)
    }

    func nameDidChainged(name: String) {
        walletName = name
    }

    func didLoad(view: BackupWalletNameViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - BackupWalletNameInteractorOutput

extension BackupWalletNamePresenter: BackupWalletNameInteractorOutput {}

// MARK: - Localizable

extension BackupWalletNamePresenter: Localizable {
    func applyLocalization() {}
}

extension BackupWalletNamePresenter: BackupWalletNameModuleInput {}
