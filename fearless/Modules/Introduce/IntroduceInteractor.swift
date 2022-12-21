import UIKit

final class IntroduceInteractor {
    // MARK: - Private properties
    private weak var output: IntroduceInteractorOutput?
}

// MARK: - IntroduceInteractorInput
extension IntroduceInteractor: IntroduceInteractorInput {
    func setup(with output: IntroduceInteractorOutput) {
        self.output = output
    }
}
