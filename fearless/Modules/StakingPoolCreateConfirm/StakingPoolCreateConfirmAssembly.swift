import UIKit
import SoraFoundation
import SoraKeystore

// swiftlint:disable function_body_length
final class StakingPoolCreateConfirmAssembly {
    static func configureModule(
        with createData: StakingPoolCreateData
    ) -> StakingPoolCreateConfirmModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = createData.chainAsset

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let accountResponse = createData.root.fetch(for: chainAsset.chain.accountRequest()) else {
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

        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: createData.root.metaId,
            accountResponse: accountResponse
        )

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager,
            logger: logger
        )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        let interactor = StakingPoolCreateConfirmInteractor(
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            createData: createData,
            signingWrapper: signingWrapper,
            callFactory: callFactory
        )
        let router = StakingPoolCreateConfirmRouter()

        let assetInfo = createData.chainAsset.asset.displayInfo(with: createData.chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: createData.root
        )

        let presenter = StakingPoolCreateConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: StakingPoolCreateConfirmViewModelFactory(
                chainAsset: createData.chainAsset,
                assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
            ),
            createData: createData,
            balanceViewModelFactory: balanceViewModelFactory,
            logger: logger
        )

        let view = StakingPoolCreateConfirmViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
