import UIKit

final class BalanceLocksDetailInteractor {
    // MARK: - Private properties

    private weak var output: BalanceLocksDetailInteractorOutput?
}

// MARK: - BalanceLocksDetailInteractorInput

extension BalanceLocksDetailInteractor: BalanceLocksDetailInteractorInput {
    func setup(with output: BalanceLocksDetailInteractorOutput) {
        self.output = output
    }
}
