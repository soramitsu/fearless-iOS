import UIKit
import SoraFoundation
import SoraUI

final class PolkaswapTransaktionSettingsAssembly {
    static func configureModule(
        markets: [LiquiditySourceType],
        selectedMarket: LiquiditySourceType,
        slippadgeTolerance: Float,
        moduleOutput: PolkaswapTransaktionSettingsModuleOutput
    ) -> PolkaswapTransaktionSettingsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = PolkaswapTransaktionSettingsInteractor()
        let router = PolkaswapTransaktionSettingsRouter()

        let presenter = PolkaswapTransaktionSettingsPresenter(
            markets: markets,
            selectedMarket: selectedMarket,
            slippadgeTolerance: slippadgeTolerance,
            slippageToleranceViewModelFactory: SlippageToleranceViewModelFactory(),
            moduleOutput: moduleOutput,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = PolkaswapTransaktionSettingsViewController(
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
