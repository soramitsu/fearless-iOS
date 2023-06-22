import UIKit
import SoraFoundation
import SSFCloudStorage

final class BackupSelectWalletAssembly {
    static func configureModule(
        accounts: [OpenBackupAccount]
    ) -> BackupSelectWalletModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = BackupSelectWalletInteractor()
        let router = BackupSelectWalletRouter()

        let presenter = BackupSelectWalletPresenter(
            accounts: accounts,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = BackupSelectWalletViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
