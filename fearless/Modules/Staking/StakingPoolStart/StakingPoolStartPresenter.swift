import Foundation
import SoraFoundation

final class StakingPoolStartPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolStartViewInput?
    private let router: StakingPoolStartRouterInput
    private let interactor: StakingPoolStartInteractorInput
    private let viewModelFactory: StakingPoolStartViewModelFactoryProtocol

    // MARK: - Constructors

    init(
        interactor: StakingPoolStartInteractorInput,
        router: StakingPoolStartRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: StakingPoolStartViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            rewardsDelayInDays: 2,
            apr: 18,
            unstakePeriodInDays: 7,
            rewardsFreqInDays: 2,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - StakingPoolStartViewOutput

extension StakingPoolStartPresenter: StakingPoolStartViewOutput {
    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapJoinPoolButton() {}

    func didTapCreatePoolButton() {}

    func didTapWatchAboutButton() {
        guard let url = ApplicationConfig().poolStakingAboutURL, let view = view else {
            return
        }

        router.showWeb(url: url, from: view, style: .automatic)
    }

    func didLoad(view: StakingPoolStartViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideViewModel()

        view.didReceive(locale: selectedLocale)
    }
}

// MARK: - StakingPoolStartInteractorOutput

extension StakingPoolStartPresenter: StakingPoolStartInteractorOutput {}

// MARK: - Localizable

extension StakingPoolStartPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}

extension StakingPoolStartPresenter: StakingPoolStartModuleInput {}
