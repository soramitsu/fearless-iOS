import Foundation
import UIKit
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFUtils
import SSFChainRegistry
import SSFNetwork
import SSFStorageQueryKit
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

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
    private let pricesService: PricesServiceProtocol
    private let appOwnedMnemonicProvider: UniversalWalletRootMnemonicProviding
    private let notificationCenter: NotificationCenter
    private let appOwnedProvisioningLock = NSLock()
    private var appOwnedProvisioningWalletIds = Set<MetaAccountId>()
    private var appOwnedProvisioningObservers: [NSObjectProtocol] = []

    init(
        walletSettings: SelectedWalletSettings,
        accountInfoService: AccountInfoUpdatingServiceProtocol,
        githubPhishingService: ApplicationServiceProtocol,
        scamSyncService: ScamSyncServiceProtocol,
        polkaswapSettingsService: PolkaswapSettingsSyncServiceProtocol,
        walletConnect: WalletConnectService,
        walletAssetsObserver: WalletAssetsObserver,
        pricesService: PricesServiceProtocol,
        bitcoinMnemonicProvider: UniversalWalletRootMnemonicProviding = KeychainUniversalWalletMnemonicProvider(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.walletSettings = walletSettings
        self.accountInfoService = accountInfoService
        self.githubPhishingService = githubPhishingService
        self.scamSyncService = scamSyncService
        self.polkaswapSettingsService = polkaswapSettingsService
        self.walletConnect = walletConnect
        self.walletAssetsObserver = walletAssetsObserver
        self.pricesService = pricesService
        appOwnedMnemonicProvider = bitcoinMnemonicProvider
        self.notificationCenter = notificationCenter
    }

    deinit {
        removeAppOwnedProvisioningObservers()
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        if let seletedMetaAccount = walletSettings.value {
            accountInfoService.update(selectedMetaAccount: seletedMetaAccount)
            walletAssetsObserver.update(wallet: seletedMetaAccount)
            provisionAppOwnedAccountsIfNeeded(for: seletedMetaAccount)
        }
    }

    func setup() {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        chainRegistry.subscribeToChains()
        chainRegistry.syncUp()

        githubPhishingService.setup()
        accountInfoService.setup()
        scamSyncService.syncUp()
        polkaswapSettingsService.syncUp()
        walletConnect.setup()
        walletAssetsObserver.setup()
        pricesService.setup()
        observeAppOwnedProvisioningRetryEvents()

        if let selectedMetaAccount = walletSettings.value {
            provisionAppOwnedAccountsIfNeeded(for: selectedMetaAccount)
        }
    }

    func throttle() {
        githubPhishingService.throttle()
        accountInfoService.throttle()
        walletConnect.throttle()
        walletAssetsObserver.throttle()
        removeAppOwnedProvisioningObservers()
    }
}

private extension ServiceCoordinator {
    func observeAppOwnedProvisioningRetryEvents() {
        guard appOwnedProvisioningObservers.isEmpty else {
            return
        }

        let retry: (Notification) -> Void = { [weak self] _ in
            guard let self, let wallet = self.walletSettings.value else {
                return
            }
            self.provisionAppOwnedAccountsIfNeeded(for: wallet)
        }
        appOwnedProvisioningObservers = [
            notificationCenter.addObserver(
                forName: UIApplication.protectedDataDidBecomeAvailableNotification,
                object: nil,
                queue: .main,
                using: retry
            ),
            notificationCenter.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main,
                using: retry
            )
        ]
    }

    func removeAppOwnedProvisioningObservers() {
        appOwnedProvisioningObservers.forEach { notificationCenter.removeObserver($0) }
        appOwnedProvisioningObservers.removeAll()
    }

    func provisionAppOwnedAccountsIfNeeded(for wallet: MetaAccountModel) {
        appOwnedProvisioningLock.lock()
        let shouldProvision = appOwnedProvisioningWalletIds.insert(wallet.metaId).inserted
        appOwnedProvisioningLock.unlock()
        guard shouldProvision else {
            return
        }

        do {
            guard let mnemonic = try appOwnedMnemonicProvider.rootMnemonic(for: wallet) else {
                finishAppOwnedProvisioning(for: wallet.metaId)
                return
            }

            let updatedWallet = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
                to: wallet,
                mnemonic: mnemonic
            )
            guard updatedWallet != wallet else {
                finishAppOwnedProvisioning(for: wallet.metaId)
                return
            }
            walletSettings.save(
                value: updatedWallet,
                runningCompletionIn: nil
            ) { [weak self] result in
                guard let self else {
                    return
                }

                self.finishAppOwnedProvisioning(for: wallet.metaId)
                switch result {
                case let .success(savedWallet):
                    self.accountInfoService.update(selectedMetaAccount: savedWallet)
                    self.walletAssetsObserver.update(wallet: savedWallet)
                    EventCenter.shared.notify(
                        with: MetaAccountModelChangedEvent(account: savedWallet)
                    )
                case let .failure(error):
                    Logger.shared.error(
                        "App-owned account provisioning failed: \(error.localizedDescription)"
                    )
                }
            }
        } catch {
            finishAppOwnedProvisioning(for: wallet.metaId)
            Logger.shared.error(
                "App-owned account provisioning failed: \(error.localizedDescription)"
            )
        }
    }

    func finishAppOwnedProvisioning(for walletId: MetaAccountId) {
        appOwnedProvisioningLock.lock()
        appOwnedProvisioningWalletIds.remove(walletId)
        appOwnedProvisioningLock.unlock()
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

        let ethereumBalanceRepositoryWrapper = BalanceRepositoryCacheWrapper(
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

        let tonBalanceRepositoryWrapper = BalanceRepositoryCacheWrapper(
            logger: logger,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager
        )

        let tonChainRepository = ChainRepositoryFactory().createAsyncRepository()
        let tonJettonInjector = TonJettonInjectorImpl(
            chainModelRepository: AsyncAnyRepository(tonChainRepository),
            eventCenter: EventCenter.shared,
            logger: logger
        )
        let dynamicAssetCatalogInjector = DynamicAssetCatalogInjectorImpl(
            chainModelRepository: AsyncAnyRepository(tonChainRepository),
            eventCenter: EventCenter.shared,
            logger: logger
        )

        let tonRemoteBalanceFetching = TonRemoteBalanceFetchingImpl(
            chainRegistry: chainRegistry,
            repositoryWrapper: tonBalanceRepositoryWrapper,
            jettonInjector: tonJettonInjector
        )

        let accountInfoService = AccountInfoUpdatingService(
            selectedAccount: selectedMetaAccount,
            chainRegistry: chainRegistry,
            remoteSubscriptionService: walletRemoteSubscription,
            ethereumRemoteSubscriptionService: ethereumWalletRemoteSubscription,
            logger: logger,
            eventCenter: EventCenter.shared
        )

        let ethereumRemoteBalanceFetching = EthereumRemoteBalanceFetching(
            chainRegistry: chainRegistry,
            repositoryWrapper: ethereumBalanceRepositoryWrapper
        )

        let storagePerformer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: chainRegistry
        )

        let accountInfoRemote = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumRemoteBalanceFetching,
            tonRemoteBalanceFetching: tonRemoteBalanceFetching,
            bitcoinBalanceSync: BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: BitcoinIndexerClient())),
            solanaBalanceSync: SolanaBalanceSync(client: SolanaIndexerClient()),
            dynamicAssetCatalogInjector: dynamicAssetCatalogInjector,
            storagePerformer: storagePerformer
        )

        let walletAssetsObserver = WalletAssetsObserverImpl(
            wallet: selectedMetaAccount,
            chainRegistry: chainRegistry,
            assetDiscoveryService: AssetDiscoveryServiceAdapter(accountInfoRemote: accountInfoRemote),
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
            pricesService: PricesService.shared
        )
    }

    private static func createPackageChainRegistry() -> SSFChainRegistry.ChainRegistryProtocol {
        // Use app's default registry which conforms to SSFChainRegistry.ChainRegistryProtocol
        ChainRegistryFactory.createDefaultRegistry()
    }
}
