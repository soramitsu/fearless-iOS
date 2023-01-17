import UIKit
import SoraFoundation
import SoraUI

final class SelectMarketAssembly {
    static func configureModule(
        markets: [LiquiditySourceType],
        moduleOutput: SelectMarketModuleOutput?
    ) -> SelectMarketModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = SelectMarketInteractor()
        let router = SelectMarketRouter()

        let presenter = SelectMarketPresenter(
            markets: markets,
            moduleOutput: moduleOutput,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = SelectMarketViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory

        return (view, presenter)
    }
}
