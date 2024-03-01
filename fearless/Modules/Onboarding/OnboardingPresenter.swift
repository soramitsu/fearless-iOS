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

    private func close() {
        interactor.didClose()

        switch startViewHelper.startView() {
        case .pin:
            router.showLocalAuthentication()
        case .pinSetup:
            router.showPincodeSetup()
        case .login:
            router.showLogin()
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
        close()
    }
}

// MARK: - OnboardingInteractorOutput

extension OnboardingPresenter: OnboardingInteractorOutput {
    func didReceiveOnboardingConfig(result: Result<OnboardingConfigWrapper, Error>?) {
        switch result {
        case let .success(config):
            let viewModel = pagesFactory.createPageControllers(with: config)
            view?.didReceive(viewModel: viewModel)
        case let .failure(error):
            Logger.shared.customError(error)
        case .none:
            close()
        }
    }
}

// MARK: - Localizable

extension OnboardingPresenter: Localizable {
    func applyLocalization() {}
}

extension OnboardingPresenter: OnboardingModuleInput {}
