import UIKit
import SSFModels

final class CustomValidatorListInteractor {
    weak var presenter: CustomValidatorListInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let asset: AssetModel

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        asset: AssetModel
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.asset = asset
    }
}

extension CustomValidatorListInteractor: CustomValidatorListInteractorInputProtocol {
    func setup() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }
}

extension CustomValidatorListInteractor: PriceLocalStorageSubscriber,
    PriceLocalSubscriptionHandler, AnyProviderAutoCleaning {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}
