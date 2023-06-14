import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

final class StakingBalanceInteractor: AccountFetching {
    weak var presenter: StakingBalanceInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let strategy: StakingBalanceStrategy

    var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        strategy: StakingBalanceStrategy
    ) {
        self.chainAsset = chainAsset
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.strategy = strategy
    }
}

extension StakingBalanceInteractor: StakingBalanceInteractorInputProtocol {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        strategy.setup()
    }

    func refresh() {
        strategy.setup()
    }
}

extension StakingBalanceInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceive(priceResult: result)
    }
}
