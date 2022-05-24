import Foundation
import RobinHood
import BigInt

class SelectValidatorsConfirmInteractorBase: SelectValidatorsConfirmInteractorInputProtocol,
    StakingDurationFetching {
    weak var presenter: SelectValidatorsConfirmInteractorOutputProtocol!

    let asset: AssetModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let strategy: SelectValidatorsConfirmStrategy

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        asset: AssetModel,
        strategy: SelectValidatorsConfirmStrategy
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.asset = asset
        self.strategy = strategy
    }

    // MARK: - SelectValidatorsConfirmInteractorInputProtocol

    func setup() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        strategy.setup()
    }

    func submitNomination(closure: ExtrinsicBuilderClosure?) {
        strategy.submitNomination(closure: closure)
    }

    func estimateFee(closure: ExtrinsicBuilderClosure?) {
        strategy.estimateFee(closure: closure)
    }
}

extension SelectValidatorsConfirmInteractorBase: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePrice(result: result)
    }
}
