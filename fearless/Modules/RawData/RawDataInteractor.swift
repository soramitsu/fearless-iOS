import UIKit

protocol RawDataInteractorOutput: AnyObject {}

final class RawDataInteractor {
    // MARK: - Private properties

    private weak var output: RawDataInteractorOutput?
}

// MARK: - RawDataInteractorInput

extension RawDataInteractor: RawDataInteractorInput {
    func setup(with output: RawDataInteractorOutput) {
        self.output = output
    }
}
