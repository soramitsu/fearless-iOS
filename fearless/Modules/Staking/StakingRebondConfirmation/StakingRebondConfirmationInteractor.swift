import UIKit
import SoraKeystore
import RobinHood
import BigInt
import SSFUtils
import IrohaCrypto
import SSFModels

final class StakingRebondConfirmationInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRebondConfirmationInteractorOutputProtocol!

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let strategy: StakingRebondConfirmationStrategy

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingRebondConfirmationStrategy
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

extension StakingRebondConfirmationInteractor: StakingRebondConfirmationInteractorInputProtocol {
    func setup() {
        strategy.setup()
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submit(builderClosure: builderClosure)
    }

    func estimateFee(
        builderClosure: ExtrinsicBuilderClosure?,
        reuseIdentifier: String?
    ) {
        strategy.estimateFee(
            builderClosure: builderClosure,
            reuseIdentifier: reuseIdentifier
        )
    }
}

extension StakingRebondConfirmationInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}
