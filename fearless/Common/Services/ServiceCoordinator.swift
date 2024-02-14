import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFUtils

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

    init(
        walletSettings: SelectedWalletSettings,
        accountInfoService: AccountInfoUpdatingServiceProtocol,
        githubPhishingService: ApplicationServiceProtocol,
        scamSyncService: ScamSyncServiceProtocol,
        polkaswapSettingsService: PolkaswapSettingsSyncServiceProtocol,
        walletConnect: WalletConnectService
    ) {
        self.walletSettings = walletSettings
        self.accountInfoService = accountInfoService
        self.githubPhishingService = githubPhishingService
        self.scamSyncService = scamSyncService
        self.polkaswapSettingsService = polkaswapSettingsService
        self.walletConnect = walletConnect
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        if let seletedMetaAccount = walletSettings.value {
            accountInfoService.update(selectedMetaAccount: seletedMetaAccount)
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
    }

    func throttle() {
        githubPhishingService.throttle()
        accountInfoService.throttle()
        walletConnect.throttle()
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

        return ServiceCoordinator(
            walletSettings: walletSettings,
            accountInfoService: accountInfoService,
            githubPhishingService: githubPhishingAPIService,
            scamSyncService: scamSyncService,
            polkaswapSettingsService: polkaswapSettingsService,
            walletConnect: walletConnect
        )
    }
}
