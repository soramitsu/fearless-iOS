import UIKit

final class LiquidityPoolsListInteractor {
    // MARK: - Private properties

    private weak var output: LiquidityPoolsListInteractorOutput?
}

// MARK: - LiquidityPoolsListInteractorInput

extension LiquidityPoolsListInteractor: LiquidityPoolsListInteractorInput {
    func setup(with output: LiquidityPoolsListInteractorOutput) {
        self.output = output
    }
}
