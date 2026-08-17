import UIKit
import SoraFoundation
import SSFPolkaswap
import SSFPools
import SSFModels

final class LiquidityPoolRemoveLiquidityConfirmAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chain: ChainModel,
        liquidityPair: LiquidityPair,
        removeInfo: RemoveLiquidityInfo,
        didSubmitTransactionClosure: @escaping (String) -> Void
    ) -> LiquidityPoolRemoveLiquidityConfirmModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let lpDataService = PolkaswapLiquidityPoolServiceAssembly.buildService(for: chain, chainRegistry: chainRegistry)

        guard let lpOperationService = try? PolkaswapLiquidityPoolServiceAssembly.buildOperationService(
            for: chain,
            wallet: wallet,
            chainRegistry: chainRegistry
        ) else {
            return nil
        }

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let interactor = LiquidityPoolRemoveLiquidityInteractor(
            lpOperationService: lpOperationService,
            lpDataService: lpDataService,
            liquidityPair: liquidityPair,
            chain: chain,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            wallet: wallet
        )
        let router = LiquidityPoolRemoveLiquidityRouter()
        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let presenter = LiquidityPoolRemoveLiquidityPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            wallet: wallet,
            logger: Logger.shared,
            chain: chain,
            liquidityPair: liquidityPair,
            dataValidatingFactory: dataValidatingFactory,
            confirmViewModelFactory: LiquidityPoolSupplyConfirmViewModelFactoryDefault(),
            removeInfo: removeInfo,
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )

        let view = LiquidityPoolRemoveLiquidityConfirmViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
