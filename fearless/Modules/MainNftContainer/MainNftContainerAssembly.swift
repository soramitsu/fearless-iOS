import UIKit
import SoraFoundation

final class MainNftContainerAssembly {
    static func configureModule() -> MainNftContainerModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = MainNftContainerInteractor()
        let router = MainNftContainerRouter()

        let presenter = MainNftContainerPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = MainNftContainerViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
