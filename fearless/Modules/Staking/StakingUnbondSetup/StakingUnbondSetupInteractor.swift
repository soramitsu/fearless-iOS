import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils
import IrohaCrypto

final class StakingUnbondSetupInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingUnbondSetupInteractorOutputProtocol!

    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let strategy: StakingUnbondSetupStrategy
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        strategy: StakingUnbondSetupStrategy
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingUnbondSetupInteractor: StakingUnbondSetupInteractorInputProtocol {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        strategy.setup()
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.estimateFee(builderClosure: builderClosure)
    }
}

extension StakingUnbondSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}
