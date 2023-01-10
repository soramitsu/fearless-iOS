import Foundation
import SoraFoundation
import PayWingsOAuthSDK

final class PhoneVerificationPresenter {
    // MARK: Private properties

    private weak var view: PhoneVerificationViewInput?
    private let router: PhoneVerificationRouterInput
    private let interactor: PhoneVerificationInteractorInput
    private let logger: LoggerProtocol

    // MARK: - Constructors

    init(
        interactor: PhoneVerificationInteractorInput,
        router: PhoneVerificationRouterInput,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - PhoneVerificationViewOutput

extension PhoneVerificationPresenter: PhoneVerificationViewOutput {
    func didLoad(view: PhoneVerificationViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didTapSendButton(with phone: String) {
        interactor.requestVerificationCode(phoneNumber: phone)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapCloseButton() {
        router.close(from: view)
    }
}

// MARK: - PhoneVerificationInteractorOutput

extension PhoneVerificationPresenter: PhoneVerificationInteractorOutput {
    func didReceive(error: Error) {
        logger.error(error.localizedDescription)
    }

    func didReceive(oAuthError: PayWingsOAuthSDK.OAuthErrorCode) {
        logger.error(oAuthError.description)

        view?.didReceive(error: oAuthError.description)
    }

    func didProceed(with data: SCKYCUserDataModel, otpLength: Int) {
        router.presentVerificationCode(from: view, data: data, otpLength: otpLength)
    }
}

// MARK: - Localizable

extension PhoneVerificationPresenter: Localizable {
    func applyLocalization() {}
}

extension PhoneVerificationPresenter: PhoneVerificationModuleInput {}
