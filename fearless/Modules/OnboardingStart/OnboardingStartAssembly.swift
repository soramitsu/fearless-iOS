import UIKit
import SoraFoundation

final class OnboardingStartAssembly {
    static func configureModule(_ config: OnboardingConfigWrapper) -> OnboardingStartModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = OnboardingStartInteractor()
        let router = OnboardingStartRouter()

        let presenter = OnboardingStartPresenter(
            interactor: interactor,
            router: router,
            config: config,
            localizationManager: localizationManager
        )

        let view = OnboardingStartViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
