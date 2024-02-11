import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore
import SSFUtils
import SSFModels

final class StakingBondMoreInteractor: AccountFetching {
    weak var presenter: StakingBondMoreInteractorOutputProtocol?

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let strategy: StakingBondMoreStrategy

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingBondMoreStrategy
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingBondMoreInteractor: StakingBondMoreInteractorInputProtocol {
    func setup() {
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        strategy.setup()
    }

    func estimateFee(reuseIdentifier: String?, builderClosure: ExtrinsicBuilderClosure?) {
        strategy.estimateFee(builderClosure: builderClosure, reuseIdentifier: reuseIdentifier)
    }
}

extension StakingBondMoreInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter?.didReceivePriceData(result: result)
    }
}
