import UIKit
import SoraFoundation
import SSFPolkaswap
import SSFPools
import SSFModels

struct LiquidityPoolSupplyConfirmInputData {
    let baseAssetAmount: Decimal
    let targetAssetAmount: Decimal
    let slippageTolerance: Decimal
    let availablePools: [LiquidityPair]?
}

enum LiquidityPoolSupplyConfirmAssembly {
    static func configureModule(
        chain: ChainModel,
        wallet: MetaAccountModel,
        liquidityPair: LiquidityPair,
        inputData: LiquidityPoolSupplyConfirmInputData,
        didSubmitTransactionClosure: @escaping (String) -> Void
    ) -> LiquidityPoolSupplyConfirmModuleCreationResult? {
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

        let interactor = LiquidityPoolSupplyConfirmInteractor(
            lpOperationService: lpOperationService,
            lpDataService: lpDataService,
            liquidityPair: liquidityPair,
            chain: chain,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter
        )
        let router = LiquidityPoolSupplyConfirmRouter()

        let presenter = LiquidityPoolSupplyConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            dataValidatingFactory: SendDataValidatingFactory(presentable: router),
            logger: Logger.shared,
            liquidityPair: liquidityPair,
            chain: chain,
            inputData: inputData,
            wallet: wallet,
            viewModelFactory: LiquidityPoolSupplyConfirmViewModelFactoryDefault(),
            didSubmitTransactionClosure: didSubmitTransactionClosure
        )

        let view = LiquidityPoolSupplyConfirmViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
