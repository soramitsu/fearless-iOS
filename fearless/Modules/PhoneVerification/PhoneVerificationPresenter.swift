import Foundation
import SoraFoundation

final class PhoneVerificationPresenter {
    // MARK: Private properties
    private weak var view: PhoneVerificationViewInput?
    private let router: PhoneVerificationRouterInput
    private let interactor: PhoneVerificationInteractorInput

    // MARK: - Constructors
    init(
        interactor: PhoneVerificationInteractorInput,
        router: PhoneVerificationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
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
}

// MARK: - PhoneVerificationInteractorOutput
extension PhoneVerificationPresenter: PhoneVerificationInteractorOutput {}

// MARK: - Localizable
extension PhoneVerificationPresenter: Localizable {
    func applyLocalization() {}
}

extension PhoneVerificationPresenter: PhoneVerificationModuleInput {}
