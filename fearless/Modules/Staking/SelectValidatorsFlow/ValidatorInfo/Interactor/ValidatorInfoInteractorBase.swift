import RobinHood

class ValidatorInfoInteractorBase: ValidatorInfoInteractorInputProtocol {
    weak var presenter: ValidatorInfoInteractorOutputProtocol!

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let asset: AssetModel
    private let strategy: ValidatorInfoStrategy

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        asset: AssetModel,
        strategy: ValidatorInfoStrategy
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.asset = asset
        self.strategy = strategy
    }

    func setup() {
        strategy.setup()

        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }

    func reload() {
        strategy.reload()
        priceProvider?.refresh()
    }
}

extension ValidatorInfoInteractorBase: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}
