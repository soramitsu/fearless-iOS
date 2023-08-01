import UIKit
import SSFCloudStorage
import RobinHood

protocol BackupSelectWalletInteractorOutput: AnyObject {
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>)
}

final class BackupSelectWalletInteractor {
    var cloudStorageService: FearlessCompatibilityProtocol?

    // MARK: - Private properties

    private weak var output: BackupSelectWalletInteractorOutput?

    // MARK: - Private methods
}

// MARK: - BackupSelectWalletInteractorInput

extension BackupSelectWalletInteractor: BackupSelectWalletInteractorInput {
    func fetchBackupAccounts() {
        Task {
            do {
                guard let cloudStorageService = cloudStorageService else {
                    throw ConvenienceError(error: "Cloud storage not init")
                }
                let accounts = try await cloudStorageService.getFearlessBackupAccounts()
                self.output?.didReceiveBackupAccounts(result: .success(accounts))
            } catch {
                self.output?.didReceiveBackupAccounts(result: .failure(error))
            }
        }
    }

    func setup(with output: BackupSelectWalletInteractorOutput) {
        self.output = output
    }
}
