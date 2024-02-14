import SoraKeystore
import RobinHood
import BigInt
import SSFUtils
import IrohaCrypto
import SSFModels

final class StakingUnbondSetupInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingUnbondSetupInteractorOutputProtocol!

    let wallet: MetaAccountModel
    let chainAsset: ChainAsset
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    let strategy: StakingUnbondSetupStrategy
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        strategy: StakingUnbondSetupStrategy
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingUnbondSetupInteractor: StakingUnbondSetupInteractorInputProtocol {
    func setup() {
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        strategy.setup()
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String) {
        strategy.estimateFee(builderClosure: builderClosure, reuseIdentifier: reuseIdentifier)
    }
}

extension StakingUnbondSetupInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}
