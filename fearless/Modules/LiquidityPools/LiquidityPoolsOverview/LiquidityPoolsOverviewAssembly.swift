import UIKit
import SoraFoundation
import SSFModels

final class LiquidityPoolsOverviewAssembly {
    static func configureModule(wallet: MetaAccountModel, chainId: ChainModel.Id) -> LiquidityPoolsOverviewModuleCreationResult? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard
            let chain = chainRegistry.availableChains.first(where: { $0.chainId == chainId }),
            let engine = try? chainRegistry.getSubstrateConnection(for: chain)
        else {
            return nil
        }

        let transactionObserver = SubstrateTransactionObserver(engine: engine)
        let localizationManager = LocalizationManager.shared

        let interactor = LiquidityPoolsOverviewInteractor(transactionObserver: transactionObserver)
        let router = LiquidityPoolsOverviewRouter()

        let presenter = LiquidityPoolsOverviewPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            chain: chain,
            wallet: wallet
        )

        let userPoolsModule = configureUserPoolsModule(chain: chain, wallet: wallet, moduleOutput: presenter)
        let availablePoolsModule = configureAvailablePoolsModule(chain: chain, wallet: wallet, moduleOutput: presenter)

        guard let userPoolsModule, let availablePoolsModule else {
            return nil
        }

        presenter.userPoolsInput = userPoolsModule.input
        presenter.availablePoolsInput = availablePoolsModule.input

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
        wallet: MetaAccountModel,
        moduleOutput: LiquidityPoolsListModuleOutput?
    ) -> LiquidityPoolsListModuleCreationResult? {
        LiquidityPoolsListAssembly.configureUserPoolsModule(chain: chain, wallet: wallet, moduleOutput: moduleOutput, type: .embed)
    }

    private static func configureAvailablePoolsModule(
        chain: ChainModel,
        wallet: MetaAccountModel,
        moduleOutput: LiquidityPoolsListModuleOutput?
    ) -> LiquidityPoolsListModuleCreationResult? {
        LiquidityPoolsListAssembly.configureAvailablePoolsModule(chain: chain, wallet: wallet, moduleOutput: moduleOutput, type: .embed)
    }
}
