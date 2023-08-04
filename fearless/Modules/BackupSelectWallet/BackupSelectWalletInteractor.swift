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
                if let cloudStorageService = cloudStorageService {
                    cloudStorageService.disconnect()
                    let accounts = try await cloudStorageService.getFearlessBackupAccounts()
                    await MainActor.run {
                        output?.didReceiveBackupAccounts(result: .success(accounts))
                    }
                }
            } catch {
                cloudStorageService?.disconnect()
                await MainActor.run {
                    output?.didReceiveBackupAccounts(result: .failure(error))
                }
            }
        }
    }

    func setup(with output: BackupSelectWalletInteractorOutput) {
        self.output = output
    }
}
