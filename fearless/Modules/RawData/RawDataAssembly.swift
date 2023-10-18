import UIKit
import SoraFoundation
import SSFUtils

final class RawDataAssembly {
    static func configureModule(
        json: JSON
    ) -> RawDataModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = RawDataInteractor()
        let router = RawDataRouter()

        let presenter = RawDataPresenter(
            json: json,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = RawDataViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
