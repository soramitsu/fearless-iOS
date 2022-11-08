import UIKit

final class AllDoneInteractor {
    // MARK: - Private properties

    private weak var output: AllDoneInteractorOutput?
}

// MARK: - AllDoneInteractorInput

extension AllDoneInteractor: AllDoneInteractorInput {
    func setup(with output: AllDoneInteractorOutput) {
        self.output = output
    }
}
