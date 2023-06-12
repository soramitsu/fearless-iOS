import Foundation
import SoraKeystore
import CommonWallet
import RobinHood
import IrohaCrypto
import Web3
import SSFModels

final class StakingPayoutConfirmationInteractor: AccountFetching {
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let strategy: StakingPayoutConfirmationStrategy

    private var priceProvider: AnySingleValueProvider<PriceData>?

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        strategy: StakingPayoutConfirmationStrategy
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }
}

// MARK: - StakingPayoutConfirmationInteractorInputProtocol

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        strategy.setup()
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.estimateFee(builderClosure: builderClosure)
    }

    func submitPayout(builderClosure: ExtrinsicBuilderClosure?) {
        strategy.submitPayout(builderClosure: builderClosure)
    }
}

extension StakingPayoutConfirmationInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result)
    }
}
