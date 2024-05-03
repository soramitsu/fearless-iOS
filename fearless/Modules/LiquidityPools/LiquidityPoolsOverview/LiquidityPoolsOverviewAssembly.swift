import UIKit
import SoraFoundation
import SSFModels

final class LiquidityPoolsOverviewAssembly {
    static func configureModule(chain: ChainModel, wallet: MetaAccountModel) -> LiquidityPoolsOverviewModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = LiquidityPoolsOverviewInteractor()
        let router = LiquidityPoolsOverviewRouter()

        let presenter = LiquidityPoolsOverviewPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let userPoolsModule = configureUserPoolsModule(chain: chain, wallet: wallet)
        let availablePoolsModule = configureAvailablePoolsModule(chain: chain, wallet: wallet)

        guard let userPoolsModule, let availablePoolsModule else {
            return nil
        }

        let view = LiquidityPoolsOverviewViewController(
            output: presenter,
            localizationManager: localizationManager,
            userPoolsViewController: userPoolsModule.view.controller,
            availablePoolsViewController: availablePoolsModule.view.controller
        )

        return (view, presenter)
    }

    private static func configureUserPoolsModule(
        chain: ChainModel,
        wallet: MetaAccountModel
    ) -> LiquidityPoolsListModuleCreationResult? {
        LiquidityPoolsListAssembly.configureUserPoolsModule(chain: chain, wallet: wallet)
    }

    private static func configureAvailablePoolsModule(
        chain: ChainModel,
        wallet: MetaAccountModel
    ) -> LiquidityPoolsListModuleCreationResult? {
        LiquidityPoolsListAssembly.configureAvailablePoolsModule(chain: chain, wallet: wallet)
    }
}
