import UIKit

final class StakingPoolInfoInteractor {
    // MARK: - Private properties

    private weak var output: StakingPoolInfoInteractorOutput?
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let chainAsset: ChainAsset

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
    }
}

// MARK: - StakingPoolInfoInteractorInput

extension StakingPoolInfoInteractor: StakingPoolInfoInteractorInput {
    func setup(with output: StakingPoolInfoInteractorOutput) {
        self.output = output

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }
    }
}

extension StakingPoolInfoInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        output?.didReceivePriceData(result: result)
    }
}
