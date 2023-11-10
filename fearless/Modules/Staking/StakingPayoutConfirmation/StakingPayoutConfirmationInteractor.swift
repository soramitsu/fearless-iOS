import Foundation
import SoraKeystore
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt
import SSFModels

final class StakingPayoutConfirmationInteractor: AccountFetching {
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let strategy: StakingPayoutConfirmationStrategy

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

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

    private func subscribeForPrices() {
        var priceIds: [String] = []
        if let utilityPriceId = chainAsset.chain.utilityChainAssets().first?.asset.priceId {
            priceIds.append(utilityPriceId)
        }

        if let priceId = chainAsset.asset.priceId, !priceIds.contains(priceId) {
            priceIds.append(priceId)
        }

        priceProvider = subscribeToPrices(for: priceIds)
    }
}

// MARK: - StakingPayoutConfirmationInteractorInputProtocol

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        subscribeForPrices()
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
    func handlePrices(result: Result<[PriceData], Error>) {
        presenter?.didReceivePriceData(result: result)
    }
}
