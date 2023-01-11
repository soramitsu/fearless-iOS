import UIKit
import SoraFoundation

final class EmailVerificationAssembly {
    static func configureModule(with data: SCKYCUserDataModel) -> EmailVerificationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = EmailVerificationInteractor()
        let router = EmailVerificationRouter()

        let presenter = EmailVerificationPresenter(
            interactor: interactor,
            router: router,
            data: data,
            localizationManager: localizationManager
        )

        let view = EmailVerificationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
