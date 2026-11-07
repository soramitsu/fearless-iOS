import UIKit

protocol MultiSelectNetworksInteractorOutput: AnyObject {}

final class MultiSelectNetworksInteractor {
    // MARK: - Private properties

    private weak var output: MultiSelectNetworksInteractorOutput?
}

// MARK: - MultiSelectNetworksInteractorInput

extension MultiSelectNetworksInteractor: MultiSelectNetworksInteractorInput {
    func setup(with output: MultiSelectNetworksInteractorOutput) {
        self.output = output
    }
}
