import UIKit
import SoraFoundation
import SSFPolkaswap
import SSFPools
import SSFModels
import SoraKeystore

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
        inputData: LiquidityPoolSupplyConfirmInputData
    ) -> LiquidityPoolSupplyConfirmModuleCreationResult? {
        guard let response = wallet.fetch(for: chain.accountRequest()) else {
            return nil
        }

        guard let secretKeyData = try? fetchSecretKey(
            for: chain,
            metaId: wallet.metaId,
            accountResponse: response
        ) else {
            return nil
        }

        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let lpDataService = PolkaswapLiquidityPoolServiceAssembly.buildService(for: chain, chainRegistry: chainRegistry)
        let signingWrapperData = SigningWrapperData(publicKeyData: response.publicKey, secretKeyData: secretKeyData)

        guard let lpOperationService = try? PolkaswapLiquidityPoolServiceAssembly.buildOperationService(
            for: chain,
            wallet: wallet.utilsModel,
            chainRegistry: chainRegistry,
            signingWrapperData: signingWrapperData
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
            priceLocalSubscriber: PriceLocalStorageSubscriberImpl.shared,
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
            viewModelFactory: LiquidityPoolSupplyConfirmViewModelFactoryDefault()
        )

        let view = LiquidityPoolSupplyConfirmViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    static func fetchSecretKey(
        for chain: ChainModel,
        metaId: String,
        accountResponse: ChainAccountResponse
    ) throws -> Data {
        let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        let tag: String = chain.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

        let keystore = Keychain()
        let secretKey = try keystore.fetchKey(for: tag)
        return secretKey
    }
}
