import Foundation
import SoraFoundation

protocol BackupRiskWarningsViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {}

protocol BackupRiskWarningsInteractorInput: AnyObject {
    func setup(with output: BackupRiskWarningsInteractorOutput)
}

final class BackupRiskWarningsPresenter {
    // MARK: Private properties

    private weak var view: BackupRiskWarningsViewInput?
    private let router: BackupRiskWarningsRouterInput
    private let interactor: BackupRiskWarningsInteractorInput

    private let walletName: String

    // MARK: - Constructors

    init(
        walletName: String,
        interactor: BackupRiskWarningsInteractorInput,
        router: BackupRiskWarningsRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.walletName = walletName
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - BackupRiskWarningsViewOutput

extension BackupRiskWarningsPresenter: BackupRiskWarningsViewOutput {
    func didBackButtonTapped() {
        router.dismiss(view: view)
    }

    func didContinueButtonTapped() {}

    func didLoad(view: BackupRiskWarningsViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - BackupRiskWarningsInteractorOutput

extension BackupRiskWarningsPresenter: BackupRiskWarningsInteractorOutput {}

// MARK: - Localizable

extension BackupRiskWarningsPresenter: Localizable {
    func applyLocalization() {}
}

extension BackupRiskWarningsPresenter: BackupRiskWarningsModuleInput {}
