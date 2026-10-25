import UIKit
import SoraFoundation
import SSFPools
import SSFPolkaswap
import SSFModels

final class LiquidityPoolSupplyAssembly {
    static func configureModule(
        chain: ChainModel,
        wallet: MetaAccountModel,
        liquidityPair: LiquidityPair,
        availablePairs: [LiquidityPair]?,
        didSubmitTransactionClosure: @escaping (String) -> Void
    ) -> LiquidityPoolSupplyModuleCreationResult? {
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

        let interactor = LiquidityPoolSupplyInteractor(
            lpOperationService: lpOperationService,
            lpDataService: lpDataService,
            liquidityPair: liquidityPair,
            chain: chain,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter
        )
        let router = LiquidityPoolSupplyRouter()
        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let presenter = LiquidityPoolSupplyPresenter(
            interactor: interactor,
            router: router,
            liquidityPair: liquidityPair,
            localizationManager: localizationManager,
            chain: chain,
            logger: Logger.shared,
            wallet: wallet,
            dataValidatingFactory: dataValidatingFactory,
            viewModelFactory: LiquidityPoolSupplyViewModelFactoryDefault(),
            availablePairs: availablePairs,
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )

        let view = LiquidityPoolSupplyViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
