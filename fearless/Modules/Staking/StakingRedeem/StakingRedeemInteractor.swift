import UIKit
import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils
import IrohaCrypto

final class StakingRedeemInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRedeemInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let strategy: StakingRedeemStrategy

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingRedeemStrategy
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingRedeemInteractor: StakingRedeemInteractorInputProtocol {
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        strategy.estimateFee(builderClosure: builderClosure, reuseIdentifier: reuseIdentifier)
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submit(builderClosure: builderClosure)
    }

    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        strategy.setup()
    }
}

extension StakingRedeemInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}
