import UIKit
import SoraFoundation
import RobinHood
import SSFUtils
import SSFModels

final class StakingPoolCreateAssembly {
    static func configureModule(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        amount: Decimal?
    ) -> StakingPoolCreateModuleCreationResult? {
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
        let logger = Logger.shared

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            logger: logger
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            selectedMetaAccount: wallet
        )

        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let stakingPoolOperationFactory = StakingPoolOperationFactory(
            chainAsset: chainAsset,
            storageRequestFactory: requestFactory,
            chainRegistry: chainRegistry
        )

        let existentialDepositService = ExistentialDepositService(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )

        let callFactory = SubstrateCallFactoryDefault(runtimeService: runtimeService)

        let interactor = StakingPoolCreateInteractor(
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            priceLocalSubscriber: priceLocalSubscriber,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            stakingPoolOperationFactory: stakingPoolOperationFactory,
            operationManager: operationManager,
            existentialDepositService: existentialDepositService,
            callFactory: callFactory
        )

        let router = StakingPoolCreateRouter()
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: router,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = StakingPoolCreatePresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            balanceViewModelFactory: balanceViewModelFactory,
            viewModelFactory: StakingPoolCreateViewModelFactory(),
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared,
            wallet: wallet,
            chainAsset: chainAsset,
            amount: amount
        )

        let view = StakingPoolCreateViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
