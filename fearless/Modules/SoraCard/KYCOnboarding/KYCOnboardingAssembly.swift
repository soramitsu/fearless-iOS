import UIKit
import SoraFoundation

final class KYCOnboardingAssembly {
    static func configureModule() -> KYCOnboardingModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = KYCOnboardingInteractor()
        let router = KYCOnboardingRouter()

        let presenter = KYCOnboardingPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = KYCOnboardingViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
