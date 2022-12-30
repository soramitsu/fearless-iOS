import UIKit

final class MainNftContainerInteractor {
    // MARK: - Private properties

    private weak var output: MainNftContainerInteractorOutput?
}

// MARK: - MainNftContainerInteractorInput

extension MainNftContainerInteractor: MainNftContainerInteractorInput {
    func setup(with output: MainNftContainerInteractorOutput) {
        self.output = output
    }
}
