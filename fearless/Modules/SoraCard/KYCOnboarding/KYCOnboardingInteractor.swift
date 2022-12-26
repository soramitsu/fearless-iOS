import UIKit

final class KYCOnboardingInteractor {
    // MARK: - Private properties

    private weak var output: KYCOnboardingInteractorOutput?
}

// MARK: - KYCOnboardingInteractorInput

extension KYCOnboardingInteractor: KYCOnboardingInteractorInput {
    func setup(with output: KYCOnboardingInteractorOutput) {
        self.output = output
    }
}
