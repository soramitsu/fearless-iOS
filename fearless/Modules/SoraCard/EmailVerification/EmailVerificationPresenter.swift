import Foundation
import SoraFoundation

final class EmailVerificationPresenter {
    // MARK: Private properties

    private weak var view: EmailVerificationViewInput?
    private let router: EmailVerificationRouterInput
    private let interactor: EmailVerificationInteractorInput
    private let data: SCKYCUserDataModel

    // MARK: - Constructors

    init(
        interactor: EmailVerificationInteractorInput,
        router: EmailVerificationRouterInput,
        data: SCKYCUserDataModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.data = data
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - EmailVerificationViewOutput

extension EmailVerificationPresenter: EmailVerificationViewOutput {
    func didLoad(view: EmailVerificationViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didTapSendButton(with _: String) {}

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapCloseButton() {
        router.close(from: view)
    }
}

// MARK: - EmailVerificationInteractorOutput

extension EmailVerificationPresenter: EmailVerificationInteractorOutput {}

// MARK: - Localizable

extension EmailVerificationPresenter: Localizable {
    func applyLocalization() {}
}

extension EmailVerificationPresenter: EmailVerificationModuleInput {}
