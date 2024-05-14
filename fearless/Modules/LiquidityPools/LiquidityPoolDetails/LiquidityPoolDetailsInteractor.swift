import UIKit

final class LiquidityPoolDetailsInteractor {
    // MARK: - Private properties

    private weak var output: LiquidityPoolDetailsInteractorOutput?
}

// MARK: - LiquidityPoolDetailsInteractorInput

extension LiquidityPoolDetailsInteractor: LiquidityPoolDetailsInteractorInput {
    func setup(with output: LiquidityPoolDetailsInteractorOutput) {
        self.output = output
    }
}
