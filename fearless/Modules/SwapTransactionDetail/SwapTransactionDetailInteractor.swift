import UIKit

final class SwapTransactionDetailInteractor {
    // MARK: - Private properties

    private weak var output: SwapTransactionDetailInteractorOutput?
    private var pricesProvider: AnySingleValueProvider<PriceData>?

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let chainAsset: ChainAsset
    private let logger: LoggerProtocol

    init(
        chainAsset: ChainAsset,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.logger = logger
    }

    // MARK: - Private methods

    private func subscribeToPrice(for chainAsset: ChainAsset) {
        guard let priceId = chainAsset.asset.priceId else {
            return
        }
        pricesProvider = subscribeToPrice(for: priceId)
    }
}

// MARK: - SwapTransactionDetailInteractorInput

extension SwapTransactionDetailInteractor: SwapTransactionDetailInteractorInput {
    func setup(with output: SwapTransactionDetailInteractorOutput) {
        self.output = output

        subscribeToPrice(for: chainAsset)
    }
}

// MARK: - PriceLocalSubscriptionHandler

extension SwapTransactionDetailInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            output?.didReceive(priceData: priceData)
        case let .failure(failure):
            logger.error("\(failure)")
        }
    }
}
