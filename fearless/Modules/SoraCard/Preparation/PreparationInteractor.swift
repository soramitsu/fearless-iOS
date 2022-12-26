import UIKit

final class PreparationInteractor {
    // MARK: - Private properties

    private weak var output: PreparationInteractorOutput?
}

// MARK: - PreparationInteractorInput

extension PreparationInteractor: PreparationInteractorInput {
    func setup(with output: PreparationInteractorOutput) {
        self.output = output
    }
}
