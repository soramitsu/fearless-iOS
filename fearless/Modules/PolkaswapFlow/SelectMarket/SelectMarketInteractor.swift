import UIKit

final class SelectMarketInteractor {
    // MARK: - Private properties

    private weak var output: SelectMarketInteractorOutput?
}

// MARK: - SelectMarketInteractorInput

extension SelectMarketInteractor: SelectMarketInteractorInput {
    func setup(with output: SelectMarketInteractorOutput) {
        self.output = output
    }
}
