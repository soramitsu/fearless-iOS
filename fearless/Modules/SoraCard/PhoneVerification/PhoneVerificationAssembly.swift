import UIKit
import SoraFoundation

final class PhoneVerificationAssembly {
    static func configureModule() -> PhoneVerificationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let service: SCKYCService = .init(client: .shared)
        let interactor = PhoneVerificationInteractor(service: service)
        let router = PhoneVerificationRouter()

        let presenter = PhoneVerificationPresenter(
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            localizationManager: localizationManager
        )

        let view = PhoneVerificationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
