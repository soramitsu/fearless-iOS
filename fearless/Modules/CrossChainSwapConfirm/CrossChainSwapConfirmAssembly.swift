import UIKit
import SoraFoundation

final class CrossChainSwapConfirmAssembly {
    static func configureModule() -> CrossChainSwapConfirmModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = CrossChainSwapConfirmInteractor()
        let router = CrossChainSwapConfirmRouter()

        let presenter = CrossChainSwapConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = CrossChainSwapConfirmViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
