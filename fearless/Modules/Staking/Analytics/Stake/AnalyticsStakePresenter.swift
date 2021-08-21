import Foundation
import BigInt
import SoraFoundation

final class AnalyticsStakePresenter {
    weak var view: AnalyticsStakeViewProtocol?
    let wireframe: AnalyticsStakeWireframeProtocol
    let interactor: AnalyticsStakeInteractorInputProtocol
    private let viewModelFactory: AnalyticsStakeViewModelFactoryProtocol
    private let localizationManager: LocalizationManagerProtocol
    private let logger: LoggerProtocol?

    private var rewardsData: [SubqueryStakeChangeData]?
    private var selectedPeriod = AnalyticsPeriod.default
    private var selectedPeriodDiff = 0
    private var priceData: PriceData?
    private var stashItem: StashItem?

    init(
        interactor: AnalyticsStakeInteractorInputProtocol,
        wireframe: AnalyticsStakeWireframeProtocol,
        viewModelFactory: AnalyticsStakeViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
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
            period: selectedPeriod,
            periodDelta: selectedPeriodDiff
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
        selectedPeriodDiff = 0
        updateView()
    }

    func didSelectPrevious() {
        selectedPeriodDiff -= 1
        updateView()
    }

    func didSelectNext() {
        selectedPeriodDiff += 1
        updateView()
    }

    func handleReward(atIndex _: Int) {
        wireframe.showRewardDetails(from: view)
    }
}

extension AnalyticsStakePresenter: Localizable {
    func applyLocalization() {
        updateView()
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
