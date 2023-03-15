import Foundation
import SoraFoundation
import PayWingsOAuthSDK

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

        if data.email.isNotEmpty {
            view.didReceiveVerifyEmail(data.email)
        }
    }

    func didTapSendButton(with email: String) {
        interactor.process(email: email)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapCloseButton() {
        router.close(from: view)
    }
}

// MARK: - EmailVerificationInteractorOutput

extension EmailVerificationPresenter: EmailVerificationInteractorOutput {
    func didReceiveSignInSuccessfulStep(data _: SCKYCUserDataModel) {}

    func didReceiveSignInRequired() {}

    func didReceiveConfirmationRequired(data: SCKYCUserDataModel, autoEmailSent _: Bool) {
        view?.didReceiveVerifyEmail(data.email)
    }

    func didReceiveError(error _: PayWingsOAuthSDK.OAuthErrorCode) {}
}

// MARK: - Localizable

extension EmailVerificationPresenter: Localizable {
    func applyLocalization() {}
}

extension EmailVerificationPresenter: EmailVerificationModuleInput {}
