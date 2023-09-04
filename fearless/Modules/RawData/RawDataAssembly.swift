import UIKit
import SoraFoundation

final class RawDataAssembly {
    static func configureModule(
        text: String
    ) -> RawDataModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = RawDataInteractor()
        let router = RawDataRouter()

        let presenter = RawDataPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = RawDataViewController(
            text: text,
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
