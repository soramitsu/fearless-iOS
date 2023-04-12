import UIKit
import SoraFoundation

final class PreparationAssembly {
    static func configureModule(data: SCKYCUserDataModel) -> PreparationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = PreparationInteractor()
        let router = PreparationRouter()

        let presenter = PreparationPresenter(
            interactor: interactor,
            router: router,
            data: data,
            localizationManager: localizationManager
        )

        let view = PreparationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
