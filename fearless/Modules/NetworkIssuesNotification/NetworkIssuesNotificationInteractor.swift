import UIKit

final class NetworkIssuesNotificationInteractor {
    // MARK: - Private properties

    private weak var output: NetworkIssuesNotificationInteractorOutput?
}

// MARK: - NetworkIssuesNotificationInteractorInput

extension NetworkIssuesNotificationInteractor: NetworkIssuesNotificationInteractorInput {
    func setup(with output: NetworkIssuesNotificationInteractorOutput) {
        self.output = output
    }
}
