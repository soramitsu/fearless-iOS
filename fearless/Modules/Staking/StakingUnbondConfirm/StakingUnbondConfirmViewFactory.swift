import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

struct StakingUnbondConfirmViewFactory: StakingUnbondConfirmViewFactoryProtocol {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        amount: Decimal
    ) -> StakingUnbondConfirmViewProtocol? {
        guard let interactor = createInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        ) else {
            return nil
        }

        let wireframe = StakingUnbondConfirmWireframe()

        let presenter = createPresenter(
            chain: chain,
            asset: asset,
            interactor: interactor,
            wireframe: wireframe,
            amount: amount,
            selectedMetaAccount: selectedAccount
        )

        let view = StakingUnbondConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        chain: ChainModel,
        asset: AssetModel,
        interactor: StakingUnbondConfirmInteractorInputProtocol,
        wireframe: StakingUnbondConfirmWireframeProtocol,
        amount: Decimal,
        selectedMetaAccount: MetaAccountModel
    ) -> StakingUnbondConfirmPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: selectedMetaAccount
        )

        let confirmationViewModelFactory = StakingUnbondConfirmViewModelFactory(asset: asset)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        return StakingUnbondConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            inputAmount: amount,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain,
            asset: asset,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> StakingUnbondConfirmInteractor? {
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

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return StakingUnbondConfirmInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                selectedMetaAccount: selectedAccount
            ),
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            runtimeService: runtimeService,
            operationManager: operationManager,
            connection: connection,
            keystore: Keychain(),
            accountRepository: AnyDataProviderRepository(accountRepository)
        )
    }
}
