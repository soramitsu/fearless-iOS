import UIKit

protocol BackupWalletNameInteractorOutput: AnyObject {}

final class BackupWalletNameInteractor {
    // MARK: - Private properties

    private weak var output: BackupWalletNameInteractorOutput?
}

// MARK: - BackupWalletNameInteractorInput

extension BackupWalletNameInteractor: BackupWalletNameInteractorInput {
    func setup(with output: BackupWalletNameInteractorOutput) {
        self.output = output
    }
}
