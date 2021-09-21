import Foundation
import BigInt
import SoraFoundation

final class AnalyticsRewardsPresenter {
    weak var view: AnalyticsRewardsViewProtocol?
    let wireframe: AnalyticsRewardsWireframeProtocol
    let interactor: AnalyticsRewardsInteractorInputProtocol
    let accountIsNominator: Bool
    private let logger: LoggerProtocol?
    private let viewModelFactory: AnalyticsRewardsViewModelFactoryProtocol
    private var rewardsData: [SubqueryRewardItemData]?
    private var selectedPeriod = AnalyticsPeriod.default
    private var priceData: PriceData?
    private var stashItem: StashItem?
    private var selectedChartIndex: Int?

    init(
        interactor: AnalyticsRewardsInteractorInputProtocol,
        wireframe: AnalyticsRewardsWireframeProtocol,
        viewModelFactory: AnalyticsRewardsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol?,
        accountIsNominator: Bool,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.accountIsNominator = accountIsNominator
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let rewardsData = rewardsData else { return }
        let viewModel = viewModelFactory.createViewModel(
            from: rewardsData,
            priceData: priceData,
            period: selectedPeriod,
            selectedChartIndex: selectedChartIndex
        )
        let localizedViewModel = viewModel.value(for: selectedLocale)
        view?.reload(viewState: .loaded(localizedViewModel))
    }
}

extension AnalyticsRewardsPresenter: AnalyticsRewardsPresenterProtocol {
    func setup() {
        view?.reload(viewState: .loading)
        interactor.setup()
    }

    func reload() {
        view?.reload(viewState: .loading)
        if let stash = stashItem?.stash {
            interactor.fetchRewards(stashAddress: stash)
        }
    }

    func didSelectPeriod(_ period: AnalyticsPeriod) {
        selectedPeriod = period
        selectedChartIndex = nil
        updateView()
    }

    func handleReward(_ rewardModel: AnalyticsRewardDetailsModel) {
        wireframe.showRewardDetails(rewardModel, from: view)
    }

    func handlePendingRewardsAction() {
        guard let stashItem = stashItem else { return }
        if accountIsNominator {
            wireframe.showRewardPayoutsForNominator(from: view, stashAddress: stashItem.stash)
        } else {
            wireframe.showRewardPayoutsForValidator(from: view, stashAddress: stashItem.stash)
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

extension AnalyticsRewardsPresenter: AnalyticsRewardsInteractorOutputProtocol {
    func didReceieve(rewardItemData: Result<[SubqueryRewardItemData]?, Error>) {
        switch rewardItemData {
        case let .success(data):
            rewardsData = data
            updateView()
        case let .failure(error):
            let errorText = R.string.localizable.commonErrorNoDataRetrieved(
                preferredLanguages: selectedLocale.rLanguages
            )
            view?.reload(viewState: .error(errorText))
            logger?.error("Did receive rewards error: \(error)")
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
                interactor.fetchRewards(stashAddress: stash)
            }
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }
}
