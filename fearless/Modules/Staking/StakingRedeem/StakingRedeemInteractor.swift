import UIKit
import SoraKeystore
import RobinHood
import BigInt
import SSFUtils
import IrohaCrypto
import SSFModels

final class StakingRedeemInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRedeemInteractorOutputProtocol!

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let strategy: StakingRedeemStrategy

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingRedeemStrategy
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
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
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        strategy.setup()
    }
}

extension StakingRedeemInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}
