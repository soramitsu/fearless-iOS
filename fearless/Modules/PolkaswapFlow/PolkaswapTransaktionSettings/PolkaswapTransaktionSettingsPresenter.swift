import Foundation
import SoraFoundation

final class PolkaswapTransaktionSettingsPresenter {
    // MARK: Private properties

    private weak var view: PolkaswapTransaktionSettingsViewInput?
    private weak var moduleOutput: PolkaswapTransaktionSettingsModuleOutput?
    private let router: PolkaswapTransaktionSettingsRouterInput
    private let interactor: PolkaswapTransaktionSettingsInteractorInput

    private let slippageToleranceViewModelFactory: SlippageToleranceViewModelFactoryProtocol

    private let markets: [LiquiditySourceType]
    private let initialSelectedMarket: LiquiditySourceType = .smart
    private let intitialSlippadgeTolerance: Float = 0.5

    private var selectedMarket: LiquiditySourceType
    private var slippadgeTolerance: Float

    // MARK: - Constructors

    init(
        markets: [LiquiditySourceType],
        selectedMarket: LiquiditySourceType,
        slippadgeTolerance: Float,
        slippageToleranceViewModelFactory: SlippageToleranceViewModelFactoryProtocol,
        moduleOutput: PolkaswapTransaktionSettingsModuleOutput,
        interactor: PolkaswapTransaktionSettingsInteractorInput,
        router: PolkaswapTransaktionSettingsRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.markets = markets
        self.selectedMarket = selectedMarket
        self.slippadgeTolerance = slippadgeTolerance
        self.slippageToleranceViewModelFactory = slippageToleranceViewModelFactory
        self.moduleOutput = moduleOutput
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - PolkaswapTransaktionSettingsViewOutput

extension PolkaswapTransaktionSettingsPresenter: PolkaswapTransaktionSettingsViewOutput {
    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapResetButton() {
        didChangeSlider(value: intitialSlippadgeTolerance)
        view?.didReceive(market: initialSelectedMarket)
        selectedMarket = initialSelectedMarket
        slippadgeTolerance = intitialSlippadgeTolerance
    }

    func didTapSaveButton() {
        moduleOutput?.didReceive(market: selectedMarket, slippadgeTolerance: slippadgeTolerance)
        router.dismiss(view: view)
    }

    func didLoad(view: PolkaswapTransaktionSettingsViewInput) {
        self.view = view
        interactor.setup(with: self)

        view.didReceive(market: selectedMarket)
        didChangeSlider(value: slippadgeTolerance)
    }

    func didChangeSlider(value: Float) {
        slippadgeTolerance = value
        let viewModel = slippageToleranceViewModelFactory
            .buildViewModel(with: value, locale: selectedLocale)
        view?.didReceive(viewModel: viewModel)
    }

    func didTapSelectMarket() {
        router.showSelectMarket(
            from: view,
            markets: markets,
            moduleOutput: self
        )
    }
}

// MARK: - PolkaswapTransaktionSettingsInteractorOutput

extension PolkaswapTransaktionSettingsPresenter: PolkaswapTransaktionSettingsInteractorOutput {}

// MARK: - Localizable

extension PolkaswapTransaktionSettingsPresenter: Localizable {
    func applyLocalization() {}
}

extension PolkaswapTransaktionSettingsPresenter: PolkaswapTransaktionSettingsModuleInput {}

extension PolkaswapTransaktionSettingsPresenter: SelectMarketModuleOutput {
    func didSelect(market: LiquiditySourceType) {
        selectedMarket = market
        view?.didReceive(market: market)
    }
}
