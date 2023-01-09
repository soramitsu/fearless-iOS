import UIKit
import SoraFoundation

final class AllDoneAssembly {
    static func configureModule(
        title: String? = nil,
        description: String? = nil,
        with hashString: String,
        closure: (() -> Void)? = nil
    ) -> AllDoneModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = AllDoneInteractor()
        let router = AllDoneRouter()
        let viewModelFactory = AllDoneViewModelFactory()

        let presenter = AllDonePresenter(
            hashString: hashString,
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            closure: closure,
            title: title,
            description: description,
            localizationManager: localizationManager
        )

        let view = AllDoneViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
