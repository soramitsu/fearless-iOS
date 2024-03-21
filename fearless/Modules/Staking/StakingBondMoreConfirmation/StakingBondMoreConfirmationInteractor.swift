import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore
import SSFUtils
import SSFModels

final class StakingBondMoreConfirmationInteractor: AccountFetching {
    weak var presenter: StakingBondMoreConfirmationOutputProtocol!

    private let priceLocalSubscriber: PriceLocalStorageSubscriber

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let strategy: StakingBondMoreConfirmationStrategy

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingBondMoreConfirmationStrategy
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingBondMoreConfirmationInteractor: StakingBondMoreConfirmationInteractorInputProtocol {
    func setup() {
        priceProvider = try? priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        strategy.setup()
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        strategy.estimateFee(builderClosure: builderClosure, reuseIdentifier: reuseIdentifier)
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submit(builderClosure: builderClosure)
    }
}

extension StakingBondMoreConfirmationInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}
