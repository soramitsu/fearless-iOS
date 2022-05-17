import RobinHood

class ValidatorInfoInteractorBase: ValidatorInfoInteractorInputProtocol {
    weak var presenter: ValidatorInfoInteractorOutputProtocol!

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let asset: AssetModel

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        asset: AssetModel
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.asset = asset
    }

    func setup() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }

    func reload() {
        priceProvider?.refresh()
    }
}

extension ValidatorInfoInteractorBase: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}
