import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

final class StakingBalanceInteractor: AccountFetching {
    weak var presenter: StakingBalanceInteractorOutputProtocol?

    let chainAsset: ChainAsset
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    let strategy: StakingBalanceStrategy

    var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        chainAsset: ChainAsset,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        strategy: StakingBalanceStrategy
    ) {
        self.chainAsset = chainAsset
        self.priceLocalSubscriber = priceLocalSubscriber
        self.strategy = strategy
    }
}

extension StakingBalanceInteractor: StakingBalanceInteractorInputProtocol {
    func setup() {
        priceProvider = try? priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        strategy.setup()
    }

    func refresh() {
        strategy.setup()
    }
}

extension StakingBalanceInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter?.didReceive(priceResult: result)
    }
}
