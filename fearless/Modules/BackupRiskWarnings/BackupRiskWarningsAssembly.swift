import UIKit
import SoraFoundation

final class BackupRiskWarningsAssembly {
    static func configureModule(walletName: String) -> BackupRiskWarningsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = BackupRiskWarningsInteractor()
        let router = BackupRiskWarningsRouter()

        let presenter = BackupRiskWarningsPresenter(
            walletName: walletName,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = BackupRiskWarningsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
