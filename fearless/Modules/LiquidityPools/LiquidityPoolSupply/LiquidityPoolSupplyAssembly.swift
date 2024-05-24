import UIKit
import SoraFoundation
import SSFPools
import SSFPolkaswap
import SSFModels
import SoraKeystore

final class LiquidityPoolSupplyAssembly {
    static func configureModule(chain: ChainModel, wallet: MetaAccountModel, liquidityPair: LiquidityPair) -> LiquidityPoolSupplyModuleCreationResult? {
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

        let interactor = LiquidityPoolSupplyInteractor(lpOperationService: lpOperationService, lpDataService: lpDataService, liquidityPair: liquidityPair, priceLocalSubscriber: PriceLocalStorageSubscriberImpl.shared, chain: chain, accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter)
        let router = LiquidityPoolSupplyRouter()

        let presenter = LiquidityPoolSupplyPresenter(
            interactor: interactor,
            router: router,
            liquidityPair: liquidityPair,
            localizationManager: localizationManager,
            chain: chain,
            logger: Logger.shared,
            wallet: wallet,
            dataValidatingFactory: SendDataValidatingFactory(presentable: router)
        )

        let view = LiquidityPoolSupplyViewController(
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
