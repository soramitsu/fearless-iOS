import UIKit
import SoraFoundation
import SSFModels
import SSFPools
import SSFPolkaswap
import SoraKeystore

final class LiquidityPoolRemoveLiquidityAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chain: ChainModel,
        liquidityPair: LiquidityPair,
        didSubmitTransactionClosure: @escaping (String) -> Void
    ) -> LiquidityPoolRemoveLiquidityModuleCreationResult? {
        guard
            let response = wallet.fetch(for: chain.accountRequest()),
            let secretKeyData = try? fetchSecretKey(
                for: chain,
                metaId: wallet.metaId,
                accountResponse: response
            )
        else {
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

        let interactor = LiquidityPoolRemoveLiquidityInteractor(
            lpOperationService: lpOperationService,
            lpDataService: lpDataService,
            liquidityPair: liquidityPair,
            priceLocalSubscriber: PriceLocalStorageSubscriberImpl.shared,
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

    private static func fetchSecretKey(
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
