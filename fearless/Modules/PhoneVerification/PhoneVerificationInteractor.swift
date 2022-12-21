import UIKit

final class PhoneVerificationInteractor {
    // MARK: - Private properties
    private weak var output: PhoneVerificationInteractorOutput?
}

// MARK: - PhoneVerificationInteractorInput
extension PhoneVerificationInteractor: PhoneVerificationInteractorInput {
    func setup(with output: PhoneVerificationInteractorOutput) {
        self.output = output
    }
}
