import UIKit
import SoraFoundation

final class EmailVerificationAssembly {
    static func configureModule() -> EmailVerificationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = EmailVerificationInteractor()
        let router = EmailVerificationRouter()

        let presenter = EmailVerificationPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = EmailVerificationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
