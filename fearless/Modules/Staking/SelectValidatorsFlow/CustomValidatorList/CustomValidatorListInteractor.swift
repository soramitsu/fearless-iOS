import UIKit
import SSFModels

final class CustomValidatorListInteractor {
    weak var presenter: CustomValidatorListInteractorOutputProtocol!

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    let chainAsset: ChainAsset

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
    }
}

extension CustomValidatorListInteractor: CustomValidatorListInteractorInputProtocol {
    func setup() {
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
    }
}

extension CustomValidatorListInteractor: PriceLocalSubscriptionHandler, AnyProviderAutoCleaning {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}
