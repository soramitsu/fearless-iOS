import UIKit
import RobinHood
import SSFModels

final class StakingRewardDetailsInteractor {
    weak var presenter: StakingRewardDetailsInteractorOutputProtocol!
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chainAsset: ChainAsset

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(chainAsset: ChainAsset, priceLocalSubscriber: PriceLocalStorageSubscriber) {
        self.chainAsset = chainAsset
        self.priceLocalSubscriber = priceLocalSubscriber
    }
}

extension StakingRewardDetailsInteractor: StakingRewardDetailsInteractorInputProtocol {
    func setup() {
        priceProvider = try? priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
    }
}

extension StakingRewardDetailsInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceive(priceResult: result)
    }
}
