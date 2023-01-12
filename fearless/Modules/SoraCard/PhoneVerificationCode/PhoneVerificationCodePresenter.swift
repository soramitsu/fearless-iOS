import Foundation
import SoraFoundation

final class PhoneVerificationCodePresenter {
    // MARK: Private properties

    private weak var view: PhoneVerificationCodeViewInput?
    private let router: PhoneVerificationCodeRouterInput
    private let interactor: PhoneVerificationCodeInteractorInput
    private let phone: String

    // MARK: - Constructors

    init(
        interactor: PhoneVerificationCodeInteractorInput,
        router: PhoneVerificationCodeRouterInput,
        phone: String,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.phone = phone
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - PhoneVerificationCodeViewOutput

extension PhoneVerificationCodePresenter: PhoneVerificationCodeViewOutput {
    func didLoad(view: PhoneVerificationCodeViewInput) {
        self.view = view
        view.set(phone: phone)
        interactor.setup(with: self)
    }

    func send(code: String) {
        interactor.verify(code: code)
    }

    func didTapResendButton() {
        interactor.askToResendCode()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapCloseButton() {
        router.close(from: view)
    }
}

// MARK: - PhoneVerificationCodeInteractorOutput

extension PhoneVerificationCodePresenter: PhoneVerificationCodeInteractorOutput {
    func didReceiveEmailVerificationStep(data _: SCKYCUserDataModel) {}

    func didReceiveUserRegistrationStep(data: SCKYCUserDataModel) {
        router.presentIntroduce(from: view, data: data)
    }

    func didReceiveSignInSuccessfulStep(data _: SCKYCUserDataModel) {}

    func didReceive(state: SCKYCPhoneCodeState) {
        view?.didReceive(state: state)
    }
}

// MARK: - Localizable

extension PhoneVerificationCodePresenter: Localizable {
    func applyLocalization() {}
}

extension PhoneVerificationCodePresenter: PhoneVerificationCodeModuleInput {}
