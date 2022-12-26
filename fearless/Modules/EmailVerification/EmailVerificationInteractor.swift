import UIKit

final class EmailVerificationInteractor {
    // MARK: - Private properties

    private weak var output: EmailVerificationInteractorOutput?
}

// MARK: - EmailVerificationInteractorInput

extension EmailVerificationInteractor: EmailVerificationInteractorInput {
    func setup(with output: EmailVerificationInteractorOutput) {
        self.output = output
    }
}
