import UIKit

final class LiquidityPoolsOverviewInteractor {
    // MARK: - Private properties

    private weak var output: LiquidityPoolsOverviewInteractorOutput?
}

// MARK: - LiquidityPoolsOverviewInteractorInput

extension LiquidityPoolsOverviewInteractor: LiquidityPoolsOverviewInteractorInput {
    func setup(with output: LiquidityPoolsOverviewInteractorOutput) {
        self.output = output
    }
}
