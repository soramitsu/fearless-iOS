import UIKit
import SSFCloudStorage
import RobinHood

protocol BackupSelectWalletInteractorOutput: AnyObject {
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>)
}

final class BackupSelectWalletInteractor {
    var cloudStorageService: CloudStorageServiceProtocol?

    // MARK: - Private properties

    private weak var output: BackupSelectWalletInteractorOutput?

    // MARK: - Private methods
}

// MARK: - BackupSelectWalletInteractorInput

extension BackupSelectWalletInteractor: BackupSelectWalletInteractorInput {
    func fetchBackupAccounts() {
        cloudStorageService?.getBackupAccounts(completion: { [weak self] result in
            self?.output?.didReceiveBackupAccounts(result: result)
        })
    }

    func setup(with output: BackupSelectWalletInteractorOutput) {
        self.output = output
    }
}
