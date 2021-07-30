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
        let viewModel = viewModelFactory.createRewardsViewModel(
            from: rewardsData,
            priceData: priceData,
            period: selectedPeriod,
            periodDelta: selectedPeriodDiff
        )
        view?.reload(viewState: .success(viewModel.value(for: .current)))
    }
}

extension AnalyticsRewardsPresenter: AnalyticsRewardsPresenterProtocol {
    func setup() {
        view?.didStartLoading()
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

extension AnalyticsRewardsPresenter: AnalyticsRewardsInteractorOutputProtocol {
    func didReceieve(rewardItemData: Result<[SubqueryRewardItemData], Error>) {
        view?.didStopLoading()

        switch rewardItemData {
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
}
