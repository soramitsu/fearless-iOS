import UIKit
import SSFModels

final class SwapTransactionDetailInteractor {
    // MARK: - Private properties

    private weak var output: SwapTransactionDetailInteractorOutput?
    private let chainAsset: ChainAsset
    private let logger: LoggerProtocol

    init(
        chainAsset: ChainAsset,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.logger = logger
    }
}

// MARK: - SwapTransactionDetailInteractorInput

extension SwapTransactionDetailInteractor: SwapTransactionDetailInteractorInput {
    func setup(with output: SwapTransactionDetailInteractorOutput) {
        self.output = output
    }
}
