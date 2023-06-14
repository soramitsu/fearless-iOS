import UIKit
import RobinHood
import SSFModels

final class StakingRewardDetailsInteractor {
    weak var presenter: StakingRewardDetailsInteractorOutputProtocol!
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let asset: AssetModel

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(asset: AssetModel, priceLocalSubscriptionFactory: PriceProviderFactoryProtocol) {
        self.asset = asset
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
    }
}

extension StakingRewardDetailsInteractor: StakingRewardDetailsInteractorInputProtocol {
    func setup() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }
}

extension StakingRewardDetailsInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceive(priceResult: result)
    }
}
