import Foundation
import SoraFoundation

protocol PolkaswapDisclaimerViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: PolkaswapDisclaimerViewModel)
    func didReceiveDisclaimer(isRead: Bool)
}

protocol PolkaswapDisclaimerInteractorInput: AnyObject {
    func setup(with output: PolkaswapDisclaimerInteractorOutput)
    func setDisclaimerIsRead()
}

final class PolkaswapDisclaimerPresenter {
    // MARK: Private properties

    private weak var moduleOutput: PolkaswapDisclaimerModuleOutput?
    private weak var view: PolkaswapDisclaimerViewInput?
    private let router: PolkaswapDisclaimerRouterInput
    private let interactor: PolkaswapDisclaimerInteractorInput
    private let viewModelFactory: PolkaswapDisclaimerViewModelFactoryProtocol

    // MARK: - Constructors

    init(
        interactor: PolkaswapDisclaimerInteractorInput,
        router: PolkaswapDisclaimerRouterInput,
        viewModelFactory: PolkaswapDisclaimerViewModelFactoryProtocol,
        moduleOutput: PolkaswapDisclaimerModuleOutput?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.moduleOutput = moduleOutput
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(locale: selectedLocale, delegate: self)
        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - PolkaswapDisclaimerViewOutput

extension PolkaswapDisclaimerPresenter: PolkaswapDisclaimerViewOutput {
    func didLoad(view: PolkaswapDisclaimerViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }

    func didContinueButtonTapped() {
        interactor.setDisclaimerIsRead()
        moduleOutput?.disclaimerDidRead()
        router.dismiss(view: view)
    }

    func didBackButtonTapped() {
        router.dismiss(view: view)
    }
}

// MARK: - PolkaswapDisclaimerInteractorOutput

extension PolkaswapDisclaimerPresenter: PolkaswapDisclaimerInteractorOutput {
    func didReceiveDisclaimer(isRead: Bool) {
        view?.didReceiveDisclaimer(isRead: isRead)
    }
}

// MARK: - Localizable

extension PolkaswapDisclaimerPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension PolkaswapDisclaimerPresenter: PolkaswapDisclaimerModuleInput {}

// MARK: - TappedLabelDelegate

extension PolkaswapDisclaimerPresenter: TappedLabelDelegate {
    func didTappedOn(link: URL) {
        guard let view = view else { return }
        router.showWeb(url: link, from: view, style: .automatic)
    }
}
