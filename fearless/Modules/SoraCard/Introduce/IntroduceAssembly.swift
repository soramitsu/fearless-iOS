import UIKit
import SoraFoundation

final class IntroduceAssembly {
    static func configureModule(with data: SCKYCUserDataModel) -> IntroduceModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let router = IntroduceRouter()

        let presenter = IntroducePresenter(
            router: router,
            data: data,
            localizationManager: localizationManager
        )

        let view = IntroduceViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
