import UIKit

protocol CrossChainSwapConfirmInteractorOutput: AnyObject {}

final class CrossChainSwapConfirmInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainSwapConfirmInteractorOutput?
}

// MARK: - CrossChainSwapConfirmInteractorInput

extension CrossChainSwapConfirmInteractor: CrossChainSwapConfirmInteractorInput {
    func setup(with output: CrossChainSwapConfirmInteractorOutput) {
        self.output = output
    }
}
