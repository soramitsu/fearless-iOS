import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFUtils
import SSFChainRegistry
import SSFNetwork
import SSFStorageQueryKit
import SSFModels

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
    private let tonConnectService: TonConnectService
    private let toggleService: LocalToggleService

    init(
        walletSettings: SelectedWalletSettings,
        accountInfoService: AccountInfoUpdatingServiceProtocol,
        githubPhishingService: ApplicationServiceProtocol,
        scamSyncService: ScamSyncServiceProtocol,
        polkaswapSettingsService: PolkaswapSettingsSyncServiceProtocol,
        walletConnect: WalletConnectService,
        walletAssetsObserver: WalletAssetsObserver,
        tonConnectService: TonConnectService,
        toggleService: LocalToggleService
    ) {
        self.walletSettings = walletSettings
        self.accountInfoService = accountInfoService
        self.githubPhishingService = githubPhishingService
        self.scamSyncService = scamSyncService
        self.polkaswapSettingsService = polkaswapSettingsService
        self.walletConnect = walletConnect
        self.walletAssetsObserver = walletAssetsObserver
        self.tonConnectService = tonConnectService
        self.toggleService = toggleService
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
        chainRegistry.subscribeToChians()

        githubPhishingService.setup()
        accountInfoService.setup()
        scamSyncService.syncUp()
        polkaswapSettingsService.syncUp()
        walletConnect.setup()
        walletAssetsObserver.setup()
        tonConnectService.setup()
        toggleService.setup()
    }

    func throttle() {
        githubPhishingService.throttle()
        accountInfoService.throttle()
        walletConnect.throttle()
        walletAssetsObserver.throttle()
        tonConnectService.throttle()
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

        let accountInfoService = AccountInfoUpdatingService(
            selectedAccount: selectedMetaAccount,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: walletRemoteSubscription,
            logger: logger,
            eventCenter: EventCenter.shared
        )

        let accountInfoRemote = ServiceAssembly.shared.accountInfoRemoteServiceDefault()
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
            walletAssetsObserver: walletAssetsObserver,
            tonConnectService: ServiceAssembly.shared.tonConnectService(),
            toggleService: ServiceAssembly.shared.localToggle
        )
    }
}
