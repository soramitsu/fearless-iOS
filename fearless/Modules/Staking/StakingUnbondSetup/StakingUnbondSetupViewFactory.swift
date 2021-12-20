import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

struct StakingUnbondSetupViewFactory: StakingUnbondSetupViewFactoryProtocol {
    static func createView(chain: ChainModel,
                           asset: AssetModel,
                           selectedAccount: MetaAccountModel) -> StakingUnbondSetupViewProtocol? {
        guard let interactor = createInteractor(chain: chain,
                                                asset: asset,
                                                selectedAccount: selectedAccount) else {
            return nil
        }

        let wireframe = StakingUnbondSetupWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo,
                                                              limit: StakingConstants.maxAmount)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain,
            asset: asset,
            logger: Logger.shared
        )

        let view = StakingUnbondSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> StakingUnbondSetupInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let feeProxy = ExtrinsicFeeProxy()
   

        return StakingUnbondSetupInteractor(asset: asset, chain: chain, selectedMetaAccount: selectedAccount, extrinsicService: extrinsicService, feeProxy: feeProxy, runtimeService: runtimeService, operationManager: operationManager, priceLocalSubscriptionFactory: priceLocalSubscriptionFactory, stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory, walletLocalSubscriptionFactory: walletLocalSubscriptionFactory, connection: connection)
    }
}
