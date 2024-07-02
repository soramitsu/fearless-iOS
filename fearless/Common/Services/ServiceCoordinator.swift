import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFUtils
import SSFChainRegistry
import SSFNetwork
import SSFStorageQueryKit

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    func updateOnAccountChange()
}

final class ServiceCoordinator {
    private let walletSettings: SelectedWalletSettings
    private let accountInfoService: AccountInfoUpdatingServiceProtocol
    private let githubPhishingService: ApplicationServiceProtocol
    private let scamSyncService: ScamSyncServiceProtocol
    private let polkaswapSettingsService: PolkaswapSettingsSyncServiceProtocol
    private let walletConnect: WalletConnectService
    private let walletAssetsObserver: WalletAssetsObserver

    init(
        walletSettings: SelectedWalletSettings,
        accountInfoService: AccountInfoUpdatingServiceProtocol,
        githubPhishingService: ApplicationServiceProtocol,
        scamSyncService: ScamSyncServiceProtocol,
        polkaswapSettingsService: PolkaswapSettingsSyncServiceProtocol,
        walletConnect: WalletConnectService,
        walletAssetsObserver: WalletAssetsObserver
    ) {
        self.walletSettings = walletSettings
        self.accountInfoService = accountInfoService
        self.githubPhishingService = githubPhishingService
        self.scamSyncService = scamSyncService
        self.polkaswapSettingsService = polkaswapSettingsService
        self.walletConnect = walletConnect
        self.walletAssetsObserver = walletAssetsObserver
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        if let seletedMetaAccount = walletSettings.value {
            accountInfoService.update(selectedMetaAccount: seletedMetaAccount)
            walletAssetsObserver.update(wallet: seletedMetaAccount)
        }
    }

    func setup() {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        chainRegistry.syncUp()

        githubPhishingService.setup()
        accountInfoService.setup()
        scamSyncService.syncUp()
        polkaswapSettingsService.syncUp()
        walletConnect.setup()
        walletAssetsObserver.setup()
    }

    func throttle() {
        githubPhishingService.throttle()
        accountInfoService.throttle()
        walletConnect.throttle()
        walletAssetsObserver.throttle()
    }
}

extension ServiceCoordinator {
    static func createDefault(
        with selectedMetaAccount: MetaAccountModel,
        walletConnect: WalletConnectService
    ) -> ServiceCoordinatorProtocol {
        let githubPhishingAPIService = GitHubPhishingServiceFactory.createService()
        let scamSyncService = ScamSyncServiceFactory.createService()
        let polkaswapSettingsService = PolkaswapSettingsFactory.createService()

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let repository = SubstrateRepositoryFactory(storageFacade: UserDataStorageFacade.shared).createAccountInfoStorageItemRepository()
        let logger = Logger.shared
        let walletSettings = SelectedWalletSettings.shared

        let walletRemoteSubscription = WalletRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager,
            logger: logger
        )

        let ethereumBalanceRepositoryWrapper = EthereumBalanceRepositoryCacheWrapper(
            logger: logger,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager
        )

        let ethereumWalletRemoteSubscription = EthereumWalletRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            logger: logger,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager,
            repositoryWrapper: ethereumBalanceRepositoryWrapper
        )

        let accountInfoService = AccountInfoUpdatingService(
            selectedAccount: selectedMetaAccount,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: walletRemoteSubscription,
            ethereumRemoteSubscriptionService: ethereumWalletRemoteSubscription,
            logger: logger,
            eventCenter: EventCenter.shared
        )

        let runtimeMetadataRepository: AsyncCoreDataRepositoryDefault<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            SubstrateDataStorageFacade.shared.createAsyncRepository()

        let ethereumRemoteBalanceFetching = EthereumRemoteBalanceFetching(
            chainRegistry: chainRegistry,
            repositoryWrapper: ethereumBalanceRepositoryWrapper
        )

        let storagePerformer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: chainRegistry
        )

        let accountInfoRemote = AccountInfoRemoteServiceDefault(
            runtimeItemRepository: AsyncAnyRepository(runtimeMetadataRepository),
            ethereumRemoteBalanceFetching: ethereumRemoteBalanceFetching,
            storagePerformer: storagePerformer
        )

        let walletAssetsObserver = WalletAssetsObserverImpl(
            wallet: selectedMetaAccount,
            chainRegistry: chainRegistry,
            accountInfoRemote: accountInfoRemote,
            eventCenter: EventCenter.shared,
            logger: logger,
            userDefaultsStorage: SettingsManager.shared
        )

        return ServiceCoordinator(
            walletSettings: walletSettings,
            accountInfoService: accountInfoService,
            githubPhishingService: githubPhishingAPIService,
            scamSyncService: scamSyncService,
            polkaswapSettingsService: polkaswapSettingsService,
            walletConnect: walletConnect,
            walletAssetsObserver: walletAssetsObserver
        )
    }

    private static func createPackageChainRegistry() -> SSFChainRegistry.ChainRegistryProtocol {
        let chainSyncService = SSFChainRegistry.ChainSyncService(
            chainsUrl: ApplicationConfig.shared.chainsSourceUrl,
            operationQueue: OperationQueue(),
            dataFetchFactory: SSFNetwork.NetworkOperationFactory()
        )

        let chainsTypesSyncService = SSFChainRegistry.ChainsTypesSyncService(
            url: ApplicationConfig.shared.chainTypesSourceUrl,
            dataOperationFactory: SSFNetwork.NetworkOperationFactory(),
            operationQueue: OperationQueue()
        )

        let runtimeSyncService = SSFChainRegistry.RuntimeSyncService(dataOperationFactory: NetworkOperationFactory())

        let chainRegistry = SSFChainRegistry.ChainRegistry(
            runtimeProviderPool: SSFChainRegistry.RuntimeProviderPool(),
            connectionPool: SSFChainRegistry.ConnectionPool(),
            chainSyncService: chainSyncService,
            chainsTypesSyncService: chainsTypesSyncService,
            runtimeSyncService: runtimeSyncService
        )
        return chainRegistry
    }
}
