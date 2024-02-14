import RobinHood
import BigInt
import SSFModels

final class AnalyticsRewardsInteractor {
    weak var presenter: AnalyticsRewardsInteractorOutputProtocol!

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    let strategy: AnalyticsRewardsStrategy
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        strategy: AnalyticsRewardsStrategy,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.strategy = strategy
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
        self.wallet = wallet
    }
}

extension AnalyticsRewardsInteractor: AnalyticsRewardsInteractorInputProtocol {
    func fetchRewards(address: AccountAddress) {
        strategy.fetchRewards(address: address)
    }

    func setup() {
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        strategy.setup()
    }
}

extension AnalyticsRewardsInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}
