import UIKit
import SoraFoundation
import SoraKeystore

final class BackupWalletImportedAssembly {
    static func configureModule(backupAccounts: [BackupAccount]) -> BackupWalletImportedModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = BackupWalletImportedInteractor(
            secretManager: KeychainManager.shared
        )
        let router = BackupWalletImportedRouter()

        let presenter = BackupWalletImportedPresenter(
            backupAccounts: backupAccounts,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = BackupWalletImportedViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
