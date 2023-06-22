import UIKit

protocol BackupWalletImportedInteractorOutput: AnyObject {}

final class BackupWalletImportedInteractor {
    // MARK: - Private properties

    private weak var output: BackupWalletImportedInteractorOutput?
}

// MARK: - BackupWalletImportedInteractorInput

extension BackupWalletImportedInteractor: BackupWalletImportedInteractorInput {
    func setup(with output: BackupWalletImportedInteractorOutput) {
        self.output = output
    }
}
