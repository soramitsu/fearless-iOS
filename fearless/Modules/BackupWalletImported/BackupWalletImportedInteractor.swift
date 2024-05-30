import UIKit
import SoraKeystore
import SSFCloudStorage

protocol BackupWalletImportedInteractorOutput: AnyObject {}

final class BackupWalletImportedInteractor {
    var cloudStorageService: CloudStorageServiceProtocol?

    // MARK: - Private properties

    private let secretManager: SecretStoreManagerProtocol

    init(secretManager: SecretStoreManagerProtocol) {
        self.secretManager = secretManager
    }

    private weak var output: BackupWalletImportedInteractorOutput?
}

// MARK: - BackupWalletImportedInteractorInput

extension BackupWalletImportedInteractor: BackupWalletImportedInteractorInput {
    func hasPincode() -> Bool {
        secretManager.checkSecret(for: KeystoreTag.pincode.rawValue)
    }

    func setup(with output: BackupWalletImportedInteractorOutput) {
        self.output = output
    }

    func disconnect() {
        cloudStorageService?.disconnect()
    }
}
