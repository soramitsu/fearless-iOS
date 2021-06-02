import Foundation
import BigInt

final class AnalyticsPresenter {
    weak var view: AnalyticsViewProtocol?
    let wireframe: AnalyticsWireframeProtocol
    let interactor: AnalyticsInteractorInputProtocol
    let chain: Chain
    private var rewardsData = [SubscanRewardItemData]()
    private var selectedPeriod = AnalyticsPeriod.weekly
    private var priceData: PriceData?

    init(
        interactor: AnalyticsInteractorInputProtocol,
        wireframe: AnalyticsWireframeProtocol,
        chain: Chain
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
    }

    private func updateView() {
        let chartData = createViewModel(from: rewardsData, period: selectedPeriod)
        view?.didReceiveChartData(chartData)
    }

    private func createViewModel(
        from data: [SubscanRewardItemData],
        period: AnalyticsPeriod
    ) -> ChartData {
        let onlyRewards = data.filter { itemData in
            let change = RewardChange(rawValue: itemData.eventId)
            return change == .reward
        }
        let filteredByPeriod = onlyRewards
            .filter { itemData in
                itemData.timestamp >= period.timestampInterval.0 &&
                    itemData.timestamp <= period.timestampInterval.1
            }
            .sorted(by: { $0.timestamp > $1.timestamp })

        let rate: Decimal = {
            guard let priceData = priceData else { return Decimal(1) }
            return Decimal(string: priceData.price) ?? Decimal(1)
        }()

        let amounts = filteredByPeriod.map { rewardItem -> Double in
            guard
                let amountValue = BigUInt(rewardItem.amount),
                let decimal = Decimal.fromSubstrateAmount(amountValue, precision: chain.addressType.precision)
            else { return 0.0 }
            return Double(truncating: (decimal * rate) as NSNumber)
        }
        return ChartData(amounts: amounts)
    }
}

extension AnalyticsPresenter: AnalyticsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didSelectPeriod(_ period: AnalyticsPeriod) {
        selectedPeriod = period
        updateView()
    }
}

extension AnalyticsPresenter: AnalyticsInteractorOutputProtocol {
    func didReceieve(rewardItemData: Result<[SubscanRewardItemData], Error>) {
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
