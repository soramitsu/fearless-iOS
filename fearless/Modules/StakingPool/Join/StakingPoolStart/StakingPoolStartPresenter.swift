import Foundation
import SoraFoundation

final class StakingPoolStartPresenter {
    // MARK: Private properties

    private weak var view: StakingPoolStartViewInput?
    private let router: StakingPoolStartRouterInput
    private let interactor: StakingPoolStartInteractorInput
    private let viewModelFactory: StakingPoolStartViewModelFactoryProtocol
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let amount: Decimal?

    private var stakingDuration: StakingDuration?
    private var calculator: RewardCalculatorEngineProtocol?

    // MARK: - Constructors

    init(
        interactor: StakingPoolStartInteractorInput,
        router: StakingPoolStartRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: StakingPoolStartViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        amount: Decimal?
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.amount = amount
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let apr = calculator?.calculateMaxReturn(isCompound: true, period: .year)

        let viewModel = viewModelFactory.buildViewModel(
            rewardsDelay: stakingDuration?.era,
            apr: apr,
            unstakePeriod: stakingDuration?.unlocking,
            rewardsFreq: stakingDuration?.era,
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

    func didTapJoinPoolButton() {
        router.presentJoinFlow(chainAsset: chainAsset, wallet: wallet, amount: amount, from: view)
    }

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

        view.didReceive(locale: selectedLocale)

        provideViewModel()
    }
}

// MARK: - StakingPoolStartInteractorOutput

extension StakingPoolStartPresenter: StakingPoolStartInteractorOutput {
    func didReceive(stakingDuration: StakingDuration) {
        self.stakingDuration = stakingDuration

        provideViewModel()
    }

    func didReceive(error _: Error) {}

    func didReceive(calculator: RewardCalculatorEngineProtocol) {
        self.calculator = calculator

        provideViewModel()
    }

    func didReceive(calculatorError _: Error) {}
}

// MARK: - Localizable

extension StakingPoolStartPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}

extension StakingPoolStartPresenter: StakingPoolStartModuleInput {}
