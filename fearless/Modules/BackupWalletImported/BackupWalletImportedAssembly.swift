import UIKit
import SoraFoundation

final class BackupWalletImportedAssembly {
    static func configureModule(backupAccounts: [BackupAccount]) -> BackupWalletImportedModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = BackupWalletImportedInteractor()
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
