import UIKit

final class PhoneVerificationCodeInteractor {
    // MARK: - Private properties

    private weak var output: PhoneVerificationCodeInteractorOutput?
}

// MARK: - PhoneVerificationCodeInteractorInput

extension PhoneVerificationCodeInteractor: PhoneVerificationCodeInteractorInput {
    func setup(with output: PhoneVerificationCodeInteractorOutput) {
        self.output = output
    }
}
