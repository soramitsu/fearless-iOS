import UIKit
import SoraFoundation
import SSFPolkaswap
import SSFPools
import SoraKeystore
import SSFModels

final class LiquidityPoolRemoveLiquidityConfirmAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chain: ChainModel,
        liquidityPair: LiquidityPair,
        removeInfo: RemoveLiquidityInfo,
        didSubmitTransactionClosure: @escaping (String) -> Void
    ) -> LiquidityPoolRemoveLiquidityConfirmModuleCreationResult? {
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

        let interactor = LiquidityPoolRemoveLiquidityInteractor(lpOperationService: lpOperationService, lpDataService: lpDataService, liquidityPair: liquidityPair, priceLocalSubscriber: PriceLocalStorageSubscriberImpl.shared, chain: chain, accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter, wallet: wallet)
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
