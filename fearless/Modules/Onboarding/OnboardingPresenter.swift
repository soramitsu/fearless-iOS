import Foundation
import SoraFoundation

protocol OnboardingViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: OnboardingDataSource)
    func showNextPage()
}

protocol OnboardingInteractorInput: AnyObject {
    func setup(with output: OnboardingInteractorOutput)
    func didClose()
}

final class OnboardingPresenter {
    // MARK: Private properties

    private weak var view: OnboardingViewInput?
    private let router: OnboardingRouterInput
    private let interactor: OnboardingInteractorInput
    private let pagesFactory: OnboardingPagesFactoryProtocol
    private let startViewHelper: StartViewHelperProtocol

    private var pages: [RemoteImageViewModel] = []
    private var currentPage: Int = 0

    // MARK: - Constructors

    init(
        interactor: OnboardingInteractorInput,
        router: OnboardingRouterInput,
        pagesFactory: OnboardingPagesFactoryProtocol,
        startViewHelper: StartViewHelperProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.pagesFactory = pagesFactory
        self.startViewHelper = startViewHelper
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func close() async {
        interactor.didClose()

        switch startViewHelper.startView(onboardingConfig: nil) {
        case .pin:
            await router.showLocalAuthentication()
        case .pinSetup:
            await router.showPincodeSetup()
        case .login:
            await router.showLogin()
        case .onboarding, .broken:
            break
        }
    }
}

// MARK: - OnboardingViewOutput

extension OnboardingPresenter: OnboardingViewOutput {
    func didLoad(view: OnboardingViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didTapSkipButton() {
        Task {
            await close()
        }
    }
}

// MARK: - OnboardingInteractorOutput

extension OnboardingPresenter: OnboardingInteractorOutput {
    func didReceiveOnboardingConfig(_ config: OnboardingConfigWrapper) {
        let viewModel = pagesFactory.createPageControllers(with: config)
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension OnboardingPresenter: Localizable {
    func applyLocalization() {}
}

extension OnboardingPresenter: OnboardingModuleInput {}
