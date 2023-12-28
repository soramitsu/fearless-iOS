import UIKit
import RobinHood
import SSFModels

final class StakingRewardDetailsInteractor {
    weak var presenter: StakingRewardDetailsInteractorOutputProtocol!
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let chainAsset: ChainAsset

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(chainAsset: ChainAsset, priceLocalSubscriptionFactory: PriceProviderFactoryProtocol) {
        self.chainAsset = chainAsset
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
    }
}

extension StakingRewardDetailsInteractor: StakingRewardDetailsInteractorInputProtocol {
    func setup() {
        priceProvider = subscribeToPrice(for: chainAsset)
    }
}

extension StakingRewardDetailsInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceive(priceResult: result)
    }
}
