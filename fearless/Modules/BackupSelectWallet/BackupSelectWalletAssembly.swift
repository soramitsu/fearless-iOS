import UIKit
import SoraFoundation
import SSFCloudStorage
import RobinHood

final class BackupSelectWalletAssembly {
    static func configureModule(
        accounts: [OpenBackupAccount]?
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
        let cloudStorageService = CloudStorageService(uiDelegate: view)
        interactor.cloudStorageService = cloudStorageService

        return (view, presenter)
    }
}
