import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingBalanceViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> StakingBalanceViewProtocol? {
        guard let interactor = createInteractor(
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount
        ) else { return nil }

        let wireframe = StakingBalanceWireframe()
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: selectedAccount
        )

        let viewModelFactory = StakingBalanceViewModelFactory(
            asset: asset,
            balanceViewModelFactory: balanceViewModelFactory,
            timeFormatter: TotalTimeFormatter()
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            countdownTimer: CountdownTimer(),
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        )

        interactor.presenter = presenter

        let viewController = StakingBalanceViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = viewController
        dataValidatingFactory.view = viewController

        return viewController
    }

    private static func createInteractor(
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) -> StakingBalanceInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return StakingBalanceInteractor(
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            runtimeCodingService: runtimeService,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            operationManager: operationManager,
            connection: connection,
            accountRepository: AnyDataProviderRepository(accountRepository)
        )
    }
}
