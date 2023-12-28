import RobinHood
import BigInt
import SSFModels

final class AnalyticsRewardsInteractor {
    weak var presenter: AnalyticsRewardsInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let strategy: AnalyticsRewardsStrategy
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

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
        priceProvider = subscribeToPrice(for: chainAsset)

        strategy.setup()
    }
}

extension AnalyticsRewardsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}
