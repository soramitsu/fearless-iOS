import UIKit

protocol DappBrowserListInteractorOutput: AnyObject {}

final class DappBrowserListInteractor {
    // MARK: - Private properties
    private weak var output: DappBrowserListInteractorOutput?
}

// MARK: - DappBrowserListInteractorInput
extension DappBrowserListInteractor: DappBrowserListInteractorInput {
    func setup(with output: DappBrowserListInteractorOutput) {
        self.output = output
    }
}
