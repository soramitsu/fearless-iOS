import UIKit
import SoraFoundation

final class ScanQRAssembly {
    static func configureModule() -> ScanQRModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = ScanQRInteractor()
        let router = ScanQRRouter()

        let presenter = ScanQRPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = ScanQRViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
