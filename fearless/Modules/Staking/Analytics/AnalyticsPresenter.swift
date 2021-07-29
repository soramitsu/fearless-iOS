import Foundation
import BigInt

final class AnalyticsPresenter {
    weak var view: AnalyticsViewProtocol?
    let wireframe: AnalyticsWireframeProtocol
    let interactor: AnalyticsInteractorInputProtocol
    private let viewModelFactory: AnalyticsViewModelFactoryProtocol
    private var rewardsData = [SubqueryRewardItemData]()
    private var selectedPeriod = AnalyticsPeriod.default
    private var selectedPeriodDiff = 0
    private var priceData: PriceData?

    init(
        interactor: AnalyticsInteractorInputProtocol,
        wireframe: AnalyticsWireframeProtocol,
        viewModelFactory: AnalyticsViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
    }

    private func updateView() {
        // TODO: delete stub data
        let stubData = (1 ..< 100).map {
            SubqueryRewardItemData(amount: $0.description, isReward: true, timestamp: 1_624_948_052 - $0 * 100_000)
        }
        let viewModel = viewModelFactory.createRewardsViewModel(
            from: stubData, // rewardsData,
            priceData: priceData,
            period: selectedPeriod,
            periodDelta: selectedPeriodDiff
        )
        view?.configureRewards(viewModel: viewModel)
    }
}

extension AnalyticsPresenter: AnalyticsPresenterProtocol {
    func setup() {
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
}

extension AnalyticsPresenter: AnalyticsInteractorOutputProtocol {
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
