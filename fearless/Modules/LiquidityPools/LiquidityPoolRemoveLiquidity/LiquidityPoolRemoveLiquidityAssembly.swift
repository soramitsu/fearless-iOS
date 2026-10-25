import UIKit
import SoraFoundation
import SSFModels
import SSFPools
import SSFPolkaswap

final class LiquidityPoolRemoveLiquidityAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chain: ChainModel,
        liquidityPair: LiquidityPair,
        didSubmitTransactionClosure: @escaping (String) -> Void
    ) -> LiquidityPoolRemoveLiquidityModuleCreationResult? {
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
            confirmViewModelFactory: nil,
            removeInfo: nil,
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )

        let view = LiquidityPoolRemoveLiquidityViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
