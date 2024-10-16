import UIKit
import SoraFoundation
import SSFPolkaswap
import SSFModels

final class LiquidityPoolDetailsAssembly {
    static func configureModule(
        assetIdPair: AssetIdPair,
        chain: ChainModel,
        wallet: MetaAccountModel,
        input: LiquidityPoolDetailsInput,
        didSubmitTransactionClosure: @escaping (String) -> Void
    ) -> LiquidityPoolDetailsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let poolService = PolkaswapLiquidityPoolServiceAssembly.buildService(for: chain, chainRegistry: chainRegistry)

        let interactor = LiquidityPoolDetailsInteractor(
            assetIdPair: assetIdPair,
            chain: chain,
            wallet: wallet,
            liquidityPoolService: poolService
        )
        let router = LiquidityPoolDetailsRouter()

        let viewModelFactory = LiquidityPoolDetailsViewModelFactoryDefault(
            modelFactory: LiquidityPoolsModelFactoryDefault(),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let presenter = LiquidityPoolDetailsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            assetIdPair: assetIdPair,
            logger: Logger.shared,
            viewModelFactory: viewModelFactory,
            chain: chain,
            wallet: wallet,
            input: input,
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )

        let view = LiquidityPoolDetailsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
