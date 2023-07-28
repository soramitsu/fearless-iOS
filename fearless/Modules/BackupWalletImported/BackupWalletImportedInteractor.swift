import UIKit
import SoraKeystore

protocol BackupWalletImportedInteractorOutput: AnyObject {}

final class BackupWalletImportedInteractor {
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
}
