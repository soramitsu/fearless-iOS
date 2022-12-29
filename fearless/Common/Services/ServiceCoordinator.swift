import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import FearlessUtils

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    func updateOnAccountChange()
}

final class ServiceCoordinator {
    let walletSettings: SelectedWalletSettings
    let accountInfoService: AccountInfoUpdatingServiceProtocol
    let githubPhishingService: ApplicationServiceProtocol
    let scamSyncService: ScamSyncServiceProtocol

    init(
        walletSettings: SelectedWalletSettings,
        accountInfoService: AccountInfoUpdatingServiceProtocol,
        githubPhishingService: ApplicationServiceProtocol,
        scamSyncService: ScamSyncServiceProtocol
    ) {
        self.walletSettings = walletSettings
        self.accountInfoService = accountInfoService
        self.githubPhishingService = githubPhishingService
        self.scamSyncService = scamSyncService
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnNetworkDown(url _: URL) {
        // TODO: Replace with multiassets code
//        let selectedConnectionItem = settings.selectedConnection
//
//        guard let connectionItem = ConnectionItem.supportedConnections.filter { $0.type == selectedConnectionItem.type && $0.url != selectedConnectionItem.url }.randomElement() else {
//            return
//        }
//
//        settings.selectedConnection = connectionItem
//
//        updateOnNetworkChange()
//
//        eventCenter.notify(with: SelectedConnectionChanged())
    }

    func updateOnAccountChange() {
        if let seletedMetaAccount = walletSettings.value {
            accountInfoService.update(selectedMetaAccount: seletedMetaAccount)
        }
    }

    func setup() {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        chainRegistry.subscribeToChians()
        chainRegistry.syncUp()

        githubPhishingService.setup()
        accountInfoService.setup()
        scamSyncService.syncUp()
    }

    func throttle() {
        githubPhishingService.throttle()
        accountInfoService.throttle()
    }
}

extension ServiceCoordinator {
    static func createDefault(with selectedMetaAccount: MetaAccountModel) -> ServiceCoordinatorProtocol {
        let githubPhishingAPIService = GitHubPhishingServiceFactory.createService()
        let scamSyncService = ScamSyncServiceFactory.createService()

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()
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

        return ServiceCoordinator(
            walletSettings: walletSettings,
            accountInfoService: accountInfoService,
            githubPhishingService: githubPhishingAPIService,
            scamSyncService: scamSyncService
        )
    }
}

extension ServiceCoordinator: WebSocketServiceStateListener {
    func websocketNetworkDown(url: URL) {
        updateOnNetworkDown(url: url)
    }
}
