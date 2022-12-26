import Foundation
import SoraFoundation

final class TermsAndConditionsPresenter {
    // MARK: Private properties

    private weak var view: TermsAndConditionsViewInput?
    private let router: TermsAndConditionsRouterInput
    private let interactor: TermsAndConditionsInteractorInput

    // MARK: - Constructors

    init(
        interactor: TermsAndConditionsInteractorInput,
        router: TermsAndConditionsRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - TermsAndConditionsViewOutput

extension TermsAndConditionsPresenter: TermsAndConditionsViewOutput {
    func didLoad(view: TermsAndConditionsViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - TermsAndConditionsInteractorOutput

extension TermsAndConditionsPresenter: TermsAndConditionsInteractorOutput {}

// MARK: - Localizable

extension TermsAndConditionsPresenter: Localizable {
    func applyLocalization() {}
}

extension TermsAndConditionsPresenter: TermsAndConditionsModuleInput {}
