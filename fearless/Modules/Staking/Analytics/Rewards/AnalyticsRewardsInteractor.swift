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
        analyticsService?.start { [weak presenter] result in
            DispatchQueue.main.async {
                presenter?.didReceieve(rewardItemData: result)
            }
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
