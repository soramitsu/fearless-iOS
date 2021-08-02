import RobinHood

class ValidatorInfoInteractorBase: ValidatorInfoInteractorInputProtocol {
    weak var presenter: ValidatorInfoInteractorOutputProtocol!

    internal let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    private let assetId: WalletAssetId

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        walletAssetId: WalletAssetId
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        assetId = walletAssetId
    }

    func setup() {
        priceProvider = subscribeToPriceProvider(for: assetId)
    }

    func reload() {
        priceProvider?.refresh()
    }
}

extension ValidatorInfoInteractorBase: SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension ValidatorInfoInteractorBase: SingleValueProviderSubscriber {}

extension ValidatorInfoInteractorBase: AnyProviderAutoCleaning {}
