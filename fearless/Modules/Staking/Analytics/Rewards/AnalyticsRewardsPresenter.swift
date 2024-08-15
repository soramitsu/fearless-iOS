import Foundation
import BigInt
import SoraFoundation
import SSFModels

final class AnalyticsRewardsPresenter {
    weak var view: AnalyticsRewardsViewProtocol?
    let wireframe: AnalyticsRewardsWireframeProtocol
    let interactor: AnalyticsRewardsInteractorInputProtocol
    let accountIsNominator: Bool
    private let logger: LoggerProtocol?
    private let viewModelFactory: AnalyticsRewardsFlowViewModelFactoryProtocol
    private let viewModelState: AnalyticsRewardsViewModelState
    private var selectedPeriod = AnalyticsPeriod.default
    private var selectedChartIndex: Int?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel

    init(
        interactor: AnalyticsRewardsInteractorInputProtocol,
        wireframe: AnalyticsRewardsWireframeProtocol,
        viewModelFactory: AnalyticsRewardsFlowViewModelFactoryProtocol,
        viewModelState: AnalyticsRewardsViewModelState,
        localizationManager: LocalizationManagerProtocol?,
        accountIsNominator: Bool,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.logger = logger
        self.accountIsNominator = accountIsNominator
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let viewModel = viewModelFactory.createViewModel(
            viewModelState: viewModelState,
            priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency),
            period: selectedPeriod,
            selectedChartIndex: selectedChartIndex,
            locale: selectedLocale
        ) else {
            return
        }

        view?.reload(viewState: .loaded(viewModel))
    }
}

extension AnalyticsRewardsPresenter: AnalyticsRewardsInteractorOutputProtocol {}

extension AnalyticsRewardsPresenter: AnalyticsRewardsPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        view?.reload(viewState: .loading)
        interactor.setup()
    }

    func reload() {
        view?.reload(viewState: .loading)
        if let stash = viewModelState.historyAddress {
            interactor.fetchRewards(address: stash)
        }
    }

    func didSelectPeriod(_ period: AnalyticsPeriod) {
        selectedPeriod = period
        selectedChartIndex = nil
        updateView()
    }

    func handleReward(_ rewardModel: AnalyticsRewardDetailsModel) {
        wireframe.showRewardDetails(
            rewardModel,
            from: view,
            wallet: wallet,
            chainAsset: chainAsset
        )
    }

    func handlePendingRewardsAction() {
        guard viewModelState.hasPendingRewards,
              let historyAddress = viewModelState.historyAddress
        else {
            return
        }

        if accountIsNominator {
            wireframe.showRewardPayoutsForNominator(
                from: view,
                stashAddress: historyAddress,
                chainAsset: chainAsset,
                wallet: wallet
            )
        } else {
            wireframe.showRewardPayoutsForValidator(
                from: view,
                stashAddress: historyAddress,
                chainAsset: chainAsset,
                wallet: wallet
            )
        }
    }

    func didUnselectXValue() {
        selectedChartIndex = nil
        updateView()
    }

    func didSelectXValue(_ index: Int) {
        selectedChartIndex = index
        updateView()
    }
}

extension AnalyticsRewardsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}

extension AnalyticsRewardsPresenter: AnalyticsRewardsModelStateListener {
    func provideError(_ error: Error) {
        logger?.error("AnalyticsRewardsPresenter: Did receive error: \(error)")
    }

    func provideRewardsViewModel() {
        updateView()
    }
}
