import Foundation
import SoraFoundation

final class KYCOnboardingPresenter {
    // MARK: Private properties

    private weak var view: KYCOnboardingViewInput?
    private let router: KYCOnboardingRouterInput
    private let interactor: KYCOnboardingInteractorInput

    // MARK: - Constructors

    init(
        interactor: KYCOnboardingInteractorInput,
        router: KYCOnboardingRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - KYCOnboardingViewOutput

extension KYCOnboardingPresenter: KYCOnboardingViewOutput {
    func didLoad(view: KYCOnboardingViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - KYCOnboardingInteractorOutput

extension KYCOnboardingPresenter: KYCOnboardingInteractorOutput {}

// MARK: - Localizable

extension KYCOnboardingPresenter: Localizable {
    func applyLocalization() {}
}

extension KYCOnboardingPresenter: KYCOnboardingModuleInput {}
