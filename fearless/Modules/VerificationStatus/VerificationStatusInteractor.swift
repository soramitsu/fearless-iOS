import UIKit

final class VerificationStatusInteractor {
    // MARK: - Private properties
    private weak var output: VerificationStatusInteractorOutput?
}

// MARK: - VerificationStatusInteractorInput
extension VerificationStatusInteractor: VerificationStatusInteractorInput {
    func setup(with output: VerificationStatusInteractorOutput) {
        self.output = output
    }
}
