import UIKit

final class AnalyticsRewardsInteractor {
    weak var presenter: AnalyticsRewardsInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol

    private let analyticsService: AnalyticsService?
    private let assetId: WalletAssetId
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        analyticsService: AnalyticsService?,
        assetId: WalletAssetId
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.analyticsService = analyticsService
        self.assetId = assetId
    }

    private func fetchAnalyticsRewards() {
        // TODO: delete stub data
        let timestamp = Int64(Date().timeIntervalSince1970)
        let stubData = (1 ..< 100).map {
            SubqueryRewardItemData(amount: $0.description, isReward: true, timestamp: timestamp - $0 * 10000)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.presenter?.didReceieve(rewardItemData: .success(stubData))
        }
    }
}

extension AnalyticsRewardsInteractor: AnalyticsRewardsInteractorInputProtocol {
    func setup() {
        fetchAnalyticsRewards()
        priceProvider = subscribeToPriceProvider(for: assetId)
    }
}

extension AnalyticsRewardsInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}
