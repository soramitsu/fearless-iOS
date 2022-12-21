import Foundation
import SoraFoundation

final class VerificationStatusPresenter {
    // MARK: Private properties
    private weak var view: VerificationStatusViewInput?
    private let router: VerificationStatusRouterInput
    private let interactor: VerificationStatusInteractorInput

    // MARK: - Constructors
    init(
        interactor: VerificationStatusInteractorInput,
        router: VerificationStatusRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }
    
    // MARK: - Private methods
}

// MARK: - VerificationStatusViewOutput
extension VerificationStatusPresenter: VerificationStatusViewOutput {
    func didLoad(view: VerificationStatusViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - VerificationStatusInteractorOutput
extension VerificationStatusPresenter: VerificationStatusInteractorOutput {}

// MARK: - Localizable
extension VerificationStatusPresenter: Localizable {
    func applyLocalization() {}
}

extension VerificationStatusPresenter: VerificationStatusModuleInput {}
