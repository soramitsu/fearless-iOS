import UIKit
import SoraFoundation
import SSFPolkaswap
import SSFModels
import SSFStorageQueryKit
import SSFChainRegistry
import sorawallet
import SSFRuntimeCodingService

final class LiquidityPoolsListAssembly {
    static func configureAvailablePoolsModule(
        chain: ChainModel,
        wallet: MetaAccountModel,
        moduleOutput: LiquidityPoolsListModuleOutput?,
        type: LiquidityPoolListType
    ) -> LiquidityPoolsListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let poolService = PolkaswapLiquidityPoolServiceAssembly.buildService(for: chain, chainRegistry: chainRegistry)
        let interactor = AvailableLiquidityPoolsListInteractor(
            liquidityPoolService: poolService,
            priceLocalSubscriber: PriceLocalStorageSubscriberImpl.shared,
            chain: chain
        )
        let router = LiquidityPoolsListRouter()
        let viewModelFactory = AvailableLiquidityPoolsListViewModelFactoryDefault(
            modelFactory: LiquidityPoolsModelFactoryDefault(),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let presenter = AvailableLiquidityPoolsListPresenter(
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            chain: chain,
            wallet: wallet,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            moduleOutput: moduleOutput,
            type: type
        )

        let view = LiquidityPoolsListViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    static func configureUserPoolsModule(
        chain: ChainModel,
        wallet: MetaAccountModel,
        moduleOutput: LiquidityPoolsListModuleOutput?,
        type: LiquidityPoolListType
    ) -> LiquidityPoolsListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let poolService = PolkaswapLiquidityPoolServiceAssembly.buildService(for: chain, chainRegistry: chainRegistry)
        let interactor = UserLiquidityPoolsListInteractor(
            liquidityPoolService: poolService,
            priceLocalSubscriber: PriceLocalStorageSubscriberImpl.shared,
            chain: chain,
            wallet: wallet
        )
        let router = LiquidityPoolsListRouter()
        let viewModelFactory = UserLiquidityPoolsListViewModelFactoryDefault(
            modelFactory: LiquidityPoolsModelFactoryDefault(),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let presenter = UserLiquidityPoolsListPresenter(
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            chain: chain,
            wallet: wallet,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            moduleOutput: moduleOutput,
            type: type
        )

        let view = LiquidityPoolsListViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
