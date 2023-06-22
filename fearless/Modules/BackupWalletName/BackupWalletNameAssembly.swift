import UIKit
import SoraFoundation

final class BackupWalletNameAssembly {
    static func configureModule() -> BackupWalletNameModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = BackupWalletNameInteractor()
        let router = BackupWalletNameRouter()

        let presenter = BackupWalletNamePresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = BackupWalletNameViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
