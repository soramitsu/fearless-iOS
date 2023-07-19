import UIKit
import SSFCloudStorage
import RobinHood

protocol BackupSelectWalletInteractorOutput: AnyObject {
    func didReceiveBackupAccounts(result: Result<[OpenBackupAccount], Error>)
    func didReceiveWallets(result: Result<[ManagedMetaAccountModel], Error>)
}

final class BackupSelectWalletInteractor {
    var cloudStorageService: CloudStorageServiceProtocol?

    // MARK: - Private properties

    private weak var output: BackupSelectWalletInteractorOutput?

    private let operationQueue: OperationQueue
    private let walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>

    init(
        walletRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.walletRepository = walletRepository
        self.operationQueue = operationQueue
    }

    // MARK: - Private methods

    private func fetchWallets() {
        let operation = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                return
            }
            self?.output?.didReceiveWallets(result: result)
        }

        operationQueue.addOperation(operation)
    }
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
        fetchWallets()
    }
}
