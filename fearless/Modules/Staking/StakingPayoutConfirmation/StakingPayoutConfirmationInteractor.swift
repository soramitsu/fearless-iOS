import Foundation
import SoraKeystore

import RobinHood
import IrohaCrypto
import BigInt
import SSFModels

final class StakingPayoutConfirmationInteractor: AccountFetching {
    private let priceLocalSubscriber: PriceLocalStorageSubscriber

    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let strategy: StakingPayoutConfirmationStrategy

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol?

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        strategy: StakingPayoutConfirmationStrategy
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.strategy = strategy
    }

    private func subscribeForPrices() {
        priceProvider = priceLocalSubscriber.subscribeToPrices(for: [chainAsset.chain.utilityChainAssets().first, chainAsset].compactMap { $0 }, listener: self)
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

extension StakingPayoutConfirmationInteractor: PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        presenter?.didReceivePriceData(result: result)
    }
}
