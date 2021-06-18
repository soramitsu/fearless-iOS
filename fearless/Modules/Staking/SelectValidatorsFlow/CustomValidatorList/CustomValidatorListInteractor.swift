import UIKit

final class CustomValidatorListInteractor {
    weak var presenter: CustomValidatorListInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let assetId: WalletAssetId

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        assetId: WalletAssetId
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.assetId = assetId
    }
}

extension CustomValidatorListInteractor: CustomValidatorListInteractorInputProtocol {
    func setup() {
        priceProvider = subscribeToPriceProvider(for: assetId)
    }
}

extension CustomValidatorListInteractor: SingleValueProviderSubscriber,
    SingleValueSubscriptionHandler, AnyProviderAutoCleaning {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}
