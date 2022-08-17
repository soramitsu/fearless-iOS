import UIKit

final class StakingPoolMainInteractor {
    // MARK: - Private properties

    private weak var output: StakingPoolMainInteractorOutput?
}

// MARK: - StakingPoolMainInteractorInput

extension StakingPoolMainInteractor: StakingPoolMainInteractorInput {
    func setup(with output: StakingPoolMainInteractorOutput) {
        self.output = output
    }
}
