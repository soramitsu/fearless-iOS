import UIKit

final class StakingPoolStartInteractor {
    // MARK: - Private properties

    private weak var output: StakingPoolStartInteractorOutput?
}

// MARK: - StakingPoolStartInteractorInput

extension StakingPoolStartInteractor: StakingPoolStartInteractorInput {
    func setup(with output: StakingPoolStartInteractorOutput) {
        self.output = output
    }
}
