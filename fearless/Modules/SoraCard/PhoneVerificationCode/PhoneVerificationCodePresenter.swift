import Foundation
import SoraFoundation

enum PhoneVerificationCodeState {
    case editing
    case sent
    case wrong(String)
    case succeed
}

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

    func send(code _: String) {}

    func didTapSendButton() {
//        Replace to send code after implement logic
        router.presentIntroduce(from: view, phone: phone)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapCloseButton() {
        router.close(from: view)
    }
}

// MARK: - PhoneVerificationCodeInteractorOutput

extension PhoneVerificationCodePresenter: PhoneVerificationCodeInteractorOutput {}

// MARK: - Localizable

extension PhoneVerificationCodePresenter: Localizable {
    func applyLocalization() {}
}

extension PhoneVerificationCodePresenter: PhoneVerificationCodeModuleInput {}
