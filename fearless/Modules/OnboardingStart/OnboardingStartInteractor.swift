import UIKit

protocol OnboardingStartInteractorOutput: AnyObject {}

final class OnboardingStartInteractor {
    // MARK: - Private properties

    private weak var output: OnboardingStartInteractorOutput?
}

// MARK: - OnboardingStartInteractorInput

extension OnboardingStartInteractor: OnboardingStartInteractorInput {
    func setup(with output: OnboardingStartInteractorOutput) {
        self.output = output
    }
}
