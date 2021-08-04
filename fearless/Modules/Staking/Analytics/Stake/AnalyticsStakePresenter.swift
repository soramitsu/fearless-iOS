import Foundation
import BigInt

final class AnalyticsStakePresenter {
    weak var view: AnalyticsStakeViewProtocol?
    let wireframe: AnalyticsStakeWireframeProtocol
    let interactor: AnalyticsStakeInteractorInputProtocol
    private let viewModelFactory: AnalyticsStakeViewModelFactoryProtocol
    private var rewardsData = [SubqueryStakeChangeData]()
    private var selectedPeriod = AnalyticsPeriod.default
    private var selectedPeriodDiff = 0
    private var priceData: PriceData?
    private var stashItem: StashItem?

    init(
        interactor: AnalyticsStakeInteractorInputProtocol,
        wireframe: AnalyticsStakeWireframeProtocol,
        viewModelFactory: AnalyticsStakeViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(
            from: rewardsData,
            priceData: priceData,
            period: selectedPeriod,
            periodDelta: selectedPeriodDiff
        )
        view?.reload(viewState: .loaded(viewModel.value(for: .current)))
    }
}

extension AnalyticsStakePresenter: AnalyticsStakePresenterProtocol {
    func setup() {
        reload()
    }

    func reload() {
        view?.reload(viewState: .loading(true))
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

extension AnalyticsStakePresenter: AnalyticsStakeInteractorOutputProtocol {
    func didReceieve(stakeDataResult: Result<[SubqueryStakeChangeData], Error>) {
        view?.reload(viewState: .loading(false))

        switch stakeDataResult {
        case let .success(data):
            rewardsData = data
            updateView()
        case let .failure(error):
            rewardsData = []
            // handle(error: error)
            print(error)
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            updateView()
        case let .failure(error):
            print(error)
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            print(error)
        }
    }
}
