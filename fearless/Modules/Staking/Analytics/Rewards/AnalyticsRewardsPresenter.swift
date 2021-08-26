import Foundation
import BigInt
import SoraFoundation

final class AnalyticsRewardsPresenter {
    weak var view: AnalyticsRewardsViewProtocol?
    let wireframe: AnalyticsRewardsWireframeProtocol
    let interactor: AnalyticsRewardsInteractorInputProtocol
    private let logger: LoggerProtocol?
    private let viewModelFactory: AnalyticsRewardsViewModelFactoryProtocol
    private let localizationManager: LocalizationManager
    private var rewardsData: [SubqueryRewardItemData]?
    private var selectedPeriod = AnalyticsPeriod.default
    private var priceData: PriceData?
    private var stashItem: StashItem?

    init(
        interactor: AnalyticsRewardsInteractorInputProtocol,
        wireframe: AnalyticsRewardsWireframeProtocol,
        viewModelFactory: AnalyticsRewardsViewModelFactoryProtocol,
        localizationManager: LocalizationManager,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func updateView() {
        guard let rewardsData = rewardsData else { return }
        let viewModel = viewModelFactory.createViewModel(
            from: rewardsData,
            priceData: priceData,
            period: selectedPeriod
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
        updateView()
    }

    func handleReward(_ rewardModel: AnalyticsRewardDetailsModel) {
        wireframe.showRewardDetails(rewardModel, from: view)
    }

    func handlePendingRewardsAction() {
        guard let stashItem = stashItem else { return }
        wireframe.showPendingRewards(from: view, stashAddress: stashItem.stash)
    }
}

extension AnalyticsRewardsPresenter: Localizable {
    func applyLocalization() {
        updateView()
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
