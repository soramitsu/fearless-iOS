import UIKit
import SoraFoundation
import SoraKeystore

final class StakingPoolJoinConfirmAssembly {
    static func configureModule(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        inputAmount: Decimal,
        selectedPool: StakingPool
    ) -> StakingPoolJoinConfirmModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: wallet.metaId,
            accountResponse: accountResponse
        )

        let interactor = StakingPoolJoinConfirmInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            amount: inputAmount,
            pool: selectedPool,
            signingWrapper: signingWrapper
        )
        let router = StakingPoolJoinConfirmRouter()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = StakingPoolJoinConfirmViewModelFactory(
            chainAsset: chainAsset,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory
        )

        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )

        let presenter = StakingPoolJoinConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            inputAmount: inputAmount,
            pool: selectedPool,
            wallet: wallet,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            logger: logger
        )

        let view = StakingPoolJoinConfirmViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
