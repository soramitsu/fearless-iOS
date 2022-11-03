import UIKit
import SoraFoundation

final class AllDoneAssembly {
    static func configureModule(with hashString: String) -> AllDoneModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = AllDoneInteractor()
        let router = AllDoneRouter()

        let presenter = AllDonePresenter(
            hashString: hashString,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = AllDoneViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
