import UIKit

final class CreateContactInteractor {
    // MARK: - Private properties

    private weak var output: CreateContactInteractorOutput?
}

// MARK: - CreateContactInteractorInput

extension CreateContactInteractor: CreateContactInteractorInput {
    func validate(address _: String) -> Bool {
        true
    }

    func setup(with output: CreateContactInteractorOutput) {
        self.output = output
    }
}
