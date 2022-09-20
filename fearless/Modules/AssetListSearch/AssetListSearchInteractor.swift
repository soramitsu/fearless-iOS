import UIKit

final class AssetListSearchInteractor {
    // MARK: - Private properties

    private weak var output: AssetListSearchInteractorOutput?
}

// MARK: - AssetListSearchInteractorInput

extension AssetListSearchInteractor: AssetListSearchInteractorInput {
    func setup(with output: AssetListSearchInteractorOutput) {
        self.output = output
    }
}
