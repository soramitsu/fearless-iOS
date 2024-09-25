import UIKit
import SoraFoundation
import SSFModels

final class SwapContainerAssembly {
    static func configureModule(wallet: MetaAccountModel, chainAsset: ChainAsset?) -> SwapContainerModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let router = SwapContainerRouter()

        let presenter = SwapContainerPresenter(
            router: router,
            localizationManager: localizationManager
        )

        guard
            let okxModule = createOkxModule(wallet: wallet, chainAsset: chainAsset, moduleOutput: presenter),
            let polkaswapModule = createPolkaswapModule(wallet: wallet, chainAsset: chainAsset, moduleOutput: presenter)
        else {
            return nil
        }

        presenter.okxModuleInput = okxModule.input
        presenter.polkaswapModuleInput = polkaswapModule.input

        let view = SwapContainerViewController(
            output: presenter,
            localizationManager: localizationManager,
            polkaswapViewController: polkaswapModule.view.controller,
            okxViewController: okxModule.view.controller
        )

        let isPolkaswapInitial = chainAsset?.chain.isSora == true
        okxModule.view.controller.view.isHidden = isPolkaswapInitial
        polkaswapModule.view.controller.view.isHidden = !isPolkaswapInitial

        return (view, presenter)
    }

    private static func createOkxModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset?,
        moduleOutput: CrossChainSwapSetupModuleOutput?
    ) -> CrossChainSwapSetupModuleCreationResult? {
        CrossChainSwapSetupAssembly.configureModule(
            wallet: wallet,
            chainAsset: chainAsset,
            moduleOutput: moduleOutput
        )
    }

    private static func createPolkaswapModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset?,
        moduleOutput: PolkaswapAdjustmentModuleOutput?
    ) -> PolkaswapAdjustmentModuleCreationResult? {
        PolkaswapAdjustmentAssembly.configureModule(
            chainAsset: chainAsset,
            wallet: wallet,
            moduleOutput: moduleOutput
        )
    }
}
