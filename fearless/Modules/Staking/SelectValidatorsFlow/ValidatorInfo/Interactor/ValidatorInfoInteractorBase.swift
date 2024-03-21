import RobinHood
import SSFModels

class ValidatorInfoInteractorBase: ValidatorInfoInteractorInputProtocol {
    weak var presenter: ValidatorInfoInteractorOutputProtocol!

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chainAsset: ChainAsset
    private let strategy: ValidatorInfoStrategy

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset,
        strategy: ValidatorInfoStrategy
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
        self.strategy = strategy
    }

    func setup() {
        strategy.setup()
        priceProvider = try? priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
    }

    func reload() {
        strategy.reload()
        priceProvider?.refresh()
    }
}

extension ValidatorInfoInteractorBase: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}
