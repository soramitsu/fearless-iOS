import UIKit

protocol BackupSelectWalletInteractorOutput: AnyObject {}

final class BackupSelectWalletInteractor {
    // MARK: - Private properties

    private weak var output: BackupSelectWalletInteractorOutput?
}

// MARK: - BackupSelectWalletInteractorInput

extension BackupSelectWalletInteractor: BackupSelectWalletInteractorInput {
    func setup(with output: BackupSelectWalletInteractorOutput) {
        self.output = output
    }
}
