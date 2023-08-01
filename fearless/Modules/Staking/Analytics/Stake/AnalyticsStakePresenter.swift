import Foundation
import BigInt
import SoraFoundation
import SSFModels

final class AnalyticsStakePresenter {
    weak var view: AnalyticsStakeViewProtocol?
    let wireframe: AnalyticsStakeWireframeProtocol
    let interactor: AnalyticsStakeInteractorInputProtocol
    private let viewModelFactory: AnalyticsStakeViewModelFactoryProtocol
    private let logger: LoggerProtocol?
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset

    private var rewardsData: [SubqueryStakeChangeData]?
    private var selectedPeriod = AnalyticsPeriod.default
    private var priceData: PriceData?
    private var stashItem: StashItem?
    private var selectedChartIndex: Int?

    init(
        interactor: AnalyticsStakeInteractorInputProtocol,
        wireframe: AnalyticsStakeWireframeProtocol,
        viewModelFactory: AnalyticsStakeViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol?,
        logger: LoggerProtocol? = nil,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let rewardsData = rewardsData else { return }
        let viewModel = viewModelFactory.createViewModel(
            from: rewardsData,
            priceData: priceData,
            period: selectedPeriod,
            selectedChartIndex: selectedChartIndex,
            hasPendingRewards: true
        )
        view?.reload(viewState: .loaded(viewModel.value(for: selectedLocale)))
    }
}

extension AnalyticsStakePresenter: AnalyticsStakePresenterProtocol {
    func setup() {
        reload()
    }

    func reload() {
        view?.reload(viewState: .loading)
        interactor.setup()
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

    func didUnselectXValue() {
        selectedChartIndex = nil
        updateView()
    }

    func didSelectXValue(_ index: Int) {
        selectedChartIndex = index
        updateView()
    }
}

extension AnalyticsStakePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}

extension AnalyticsStakePresenter: AnalyticsStakeInteractorOutputProtocol {
    func didReceieve(stakeDataResult: Result<[SubqueryStakeChangeData], Error>) {
        switch stakeDataResult {
        case let .success(data):
            rewardsData = data
            updateView()
        case let .failure(error):
            let errorText = R.string.localizable.commonErrorNoDataRetrieved(
                preferredLanguages: selectedLocale.rLanguages
            )
            view?.reload(viewState: .error(errorText))
            logger?.error("Did receive stake error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            updateView()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
            if let stash = stashItem?.stash {
                interactor.fetchStakeHistory(stashAddress: stash)
            }
        case let .failure(error):
            logger?.error("Did receive stashItem error: \(error)")
        }
    }
}
