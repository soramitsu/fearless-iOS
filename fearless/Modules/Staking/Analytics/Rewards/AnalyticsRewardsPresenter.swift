import Foundation
import BigInt

final class AnalyticsRewardsPresenter {
    weak var view: AnalyticsRewardsViewProtocol?
    let wireframe: AnalyticsRewardsWireframeProtocol
    let interactor: AnalyticsRewardsInteractorInputProtocol
    private let viewModelFactory: AnalyticsRewardsViewModelFactoryProtocol
    private var rewardsData = [SubqueryRewardItemData]()
    private var selectedPeriod = AnalyticsPeriod.default
    private var selectedPeriodDiff = 0
    private var priceData: PriceData?

    init(
        interactor: AnalyticsRewardsInteractorInputProtocol,
        wireframe: AnalyticsRewardsWireframeProtocol,
        viewModelFactory: AnalyticsRewardsViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }

    private func updateView() {
        // TODO: delete stub data
        let stubData = (1 ..< 100).map {
            SubqueryRewardItemData(amount: $0.description, isReward: true, timestamp: 1_627_634_443 - $0 * 10000)
        }
        let viewModel = viewModelFactory.createRewardsViewModel(
            from: stubData, // rewardsData,
            priceData: priceData,
            period: selectedPeriod,
            periodDelta: selectedPeriodDiff
        )
        view?.reload(viewState: .success(viewModel.value(for: .current)))
    }
}

extension AnalyticsRewardsPresenter: AnalyticsRewardsPresenterProtocol {
    func setup() {
        interactor.setup()
        // TODO: delete
        updateView()
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
}

extension AnalyticsRewardsPresenter: AnalyticsRewardsInteractorOutputProtocol {
    func didReceieve(rewardItemData: Result<[SubqueryRewardItemData], Error>) {
        switch rewardItemData {
        case let .success(data):
            rewardsData = data
            updateView()
        case let .failure(error):
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
}
