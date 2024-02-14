import Foundation
import SoraKeystore
import RobinHood
import BigInt
import SSFUtils
import SSFModels
import IrohaCrypto

final class StakingUnbondConfirmInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingUnbondConfirmInteractorOutputProtocol!

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let strategy: StakingUnbondConfirmStrategy
    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingUnbondConfirmStrategy
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingUnbondConfirmInteractor: StakingUnbondConfirmInteractorInputProtocol {
    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submit(builderClosure: builderClosure)
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        strategy.estimateFee(
            builderClosure: builderClosure,
            reuseIdentifier: reuseIdentifier
        )
    }

    func setup() {
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        strategy.setup()
    }
}

extension StakingUnbondConfirmInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}
