import UIKit
import SSFModels

final class SwapTransactionDetailInteractor {
    // MARK: - Private properties

    private weak var output: SwapTransactionDetailInteractorOutput?
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chainAsset: ChainAsset
    private let logger: LoggerProtocol

    init(
        chainAsset: ChainAsset,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.priceLocalSubscriber = priceLocalSubscriber
        self.logger = logger
    }

    // MARK: - Private methods

    private func subscribeToPrice(for chainAsset: ChainAsset) {
        pricesProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
    }
}

// MARK: - SwapTransactionDetailInteractorInput

extension SwapTransactionDetailInteractor: SwapTransactionDetailInteractorInput {
    func setup(with output: SwapTransactionDetailInteractorOutput) {
        self.output = output

        if chainAsset.asset.isUtility {
            subscribeToPrice(for: chainAsset)
        } else {
            if let utilityChainAsset = chainAsset.chain.utilityChainAssets().first {
                subscribeToPrice(for: utilityChainAsset)
            }
        }
    }
}

// MARK: - PriceLocalSubscriptionHandler

extension SwapTransactionDetailInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        chainAsset _: ChainAsset
    ) {
        switch result {
        case let .success(priceData):
            output?.didReceive(priceData: priceData)
        case let .failure(failure):
            logger.error("\(failure)")
        }
    }
}
