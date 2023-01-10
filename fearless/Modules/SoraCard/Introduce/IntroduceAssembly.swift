import UIKit
import SoraFoundation

final class IntroduceAssembly {
    static func configureModule(with phone: String) -> IntroduceModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let router = IntroduceRouter()

        let presenter = IntroducePresenter(
            router: router,
            phone: phone,
            localizationManager: localizationManager
        )

        let view = IntroduceViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
