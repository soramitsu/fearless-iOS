import UIKit

final class TermsAndConditionsInteractor {
    // MARK: - Private properties

    private weak var output: TermsAndConditionsInteractorOutput?
}

// MARK: - TermsAndConditionsInteractorInput

extension TermsAndConditionsInteractor: TermsAndConditionsInteractorInput {
    func setup(with output: TermsAndConditionsInteractorOutput) {
        self.output = output
    }
}
