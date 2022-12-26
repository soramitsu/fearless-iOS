import Foundation
import SoraFoundation

final class EmailVerificationPresenter {
    // MARK: Private properties

    private weak var view: EmailVerificationViewInput?
    private let router: EmailVerificationRouterInput
    private let interactor: EmailVerificationInteractorInput

    // MARK: - Constructors

    init(
        interactor: EmailVerificationInteractorInput,
        router: EmailVerificationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
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
}

// MARK: - EmailVerificationInteractorOutput

extension EmailVerificationPresenter: EmailVerificationInteractorOutput {}

// MARK: - Localizable

extension EmailVerificationPresenter: Localizable {
    func applyLocalization() {}
}

extension EmailVerificationPresenter: EmailVerificationModuleInput {}
