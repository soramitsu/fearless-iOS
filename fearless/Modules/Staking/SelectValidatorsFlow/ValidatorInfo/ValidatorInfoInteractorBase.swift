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
}

extension ValidatorInfoInteractorBase: SingleValueProviderSubscriber, SingleValueSubscriptionHandler, AnyProviderAutoCleaning {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        // TODO: Refactor presenter
        switch result {
        case let .success(priceData):
            presenter?.didRecieve(priceData: priceData)
        case let .failure(error):
            presenter?.didReceive(priceError: error)
        }
    }
}
