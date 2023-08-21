import UIKit

protocol BackupRiskWarningsInteractorOutput: AnyObject {}

final class BackupRiskWarningsInteractor {
    // MARK: - Private properties

    private weak var output: BackupRiskWarningsInteractorOutput?
}

// MARK: - BackupRiskWarningsInteractorInput

extension BackupRiskWarningsInteractor: BackupRiskWarningsInteractorInput {
    func setup(with output: BackupRiskWarningsInteractorOutput) {
        self.output = output
    }
}
