import RobinHood
import BigInt

final class AnalyticsRewardsInteractor {
    weak var presenter: AnalyticsRewardsInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let strategy: AnalyticsRewardsStrategy
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        strategy: AnalyticsRewardsStrategy,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.strategy = strategy
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
    }
}

extension AnalyticsRewardsInteractor: AnalyticsRewardsInteractorInputProtocol {
    func fetchRewards(address: AccountAddress) {
        strategy.fetchRewards(address: address)
    }

    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        strategy.setup()
    }
}

extension AnalyticsRewardsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}
