import Foundation
import SoraFoundation

protocol OnboardingStartViewInput: ControllerBackedProtocol {}

protocol OnboardingStartInteractorInput: AnyObject {
    func setup(with output: OnboardingStartInteractorOutput)
}

final class OnboardingStartPresenter {
    // MARK: Private properties

    private weak var view: OnboardingStartViewInput?
    private let router: OnboardingStartRouterInput
    private let interactor: OnboardingStartInteractorInput

    // MARK: - Constructors

    init(
        interactor: OnboardingStartInteractorInput,
        router: OnboardingStartRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - OnboardingStartViewOutput

extension OnboardingStartPresenter: OnboardingStartViewOutput {
    func didLoad(view: OnboardingStartViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didTapStartButton() {
        router.startOnboarding()
    }
}

// MARK: - OnboardingStartInteractorOutput

extension OnboardingStartPresenter: OnboardingStartInteractorOutput {}

// MARK: - Localizable

extension OnboardingStartPresenter: Localizable {
    func applyLocalization() {}
}

extension OnboardingStartPresenter: OnboardingStartModuleInput {}
