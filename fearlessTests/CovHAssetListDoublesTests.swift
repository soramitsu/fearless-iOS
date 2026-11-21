import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFModels
import Web3
@testable import fearless

enum CovHAssetListFixture {
    static func chain(
        id: String = UUID().uuidString.lowercased(),
        name: String = "Cov H network",
        minVersion: String? = nil,
        options: [ChainOptions]? = nil
    ) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: id,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: [],
            addressPrefix: 42,
            types: nil,
            icon: nil,
            options: options,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: minVersion,
            identityChain: nil
        )
    }

    static func chainAsset(
        chain: ChainModel = chain(),
        id: String = "cov-h-asset",
        symbol: String = "COVH",
        precision: UInt16 = 0
    ) -> ChainAsset {
        let asset = AssetModel(
            id: id,
            name: symbol,
            symbol: symbol,
            precision: precision,
            icon: nil,
            price: nil,
            fiatDayChange: nil,
            currencyId: id,
            existentialDeposit: nil,
            color: nil,
            isUtility: true,
            isNative: true,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
        chain.assets.insert(asset)
        return ChainAsset(chain: chain, asset: asset)
    }

    /// A wallet without a Substrate root: it cannot receive app-owned Bitcoin, Solana or Taira accounts.
    static func evmOnlyWallet() -> MetaAccountModel {
        MetaAccountModel(
            metaId: UUID().uuidString,
            name: "EVM only",
            substrateAccountId: nil,
            substrateCryptoType: 0,
            substratePublicKey: nil,
            ethereumAddress: Data(repeating: 7, count: 20),
            ethereumPublicKey: Data(repeating: 8, count: 33),
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
    }

    static func spin(timeout: TimeInterval = 5, until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func drainMain() {
        var drained = false
        DispatchQueue.main.async { drained = true }
        spin { drained }
    }

    static func host(_ controller: UIViewController) -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow()
        }
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }

    static func defaults() -> UserDefaults {
        let suite = "cov-h-asset-list-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite) ?? .standard
    }
}

final class CovHAssetListOutputSpy: ChainAssetListInteractorOutput {
    private let lock = NSLock()
    private var storedEvents: [String] = []
    private var storedChainAssets: [Result<[ChainAsset], Error>] = []
    private var storedIssues: [[ChainIssue]] = []
    private var storedWallets: [MetaAccountModel] = []
    private var storedChangedWallets: [MetaAccountModel] = []
    private var storedAdoptions: [Result<MetaAccountModel, Error>] = []
    private var storedAccountInfoDeliveries = 0
    private var storedViewModelUpdates = 0

    var events: [String] { locked { storedEvents } }
    var chainAssetResults: [Result<[ChainAsset], Error>] { locked { storedChainAssets } }
    var issues: [[ChainIssue]] { locked { storedIssues } }
    var wallets: [MetaAccountModel] { locked { storedWallets } }
    var changedWallets: [MetaAccountModel] { locked { storedChangedWallets } }
    var adoptions: [Result<MetaAccountModel, Error>] { locked { storedAdoptions } }
    var accountInfoDeliveries: Int { locked { storedAccountInfoDeliveries } }
    var viewModelUpdates: Int { locked { storedViewModelUpdates } }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func record(_ event: String, _ body: () -> Void = {}) {
        locked {
            storedEvents.append(event)
            body()
        }
    }

    func didReceiveChainAssets(result: Result<[ChainAsset], Error>) {
        record("chainAssets") { storedChainAssets.append(result) }
    }

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for _: ChainAsset) {
        record("accountInfo")
    }

    func didReceiveWallet(wallet: MetaAccountModel) {
        record("wallet") { storedWallets.append(wallet) }
    }

    func didReceiveChainsWithIssues(_ issues: [ChainIssue]) {
        record("issues") { storedIssues.append(issues) }
    }

    func updateViewModel(isInitSearchState _: Bool) {
        record("update") { storedViewModelUpdates += 1 }
    }

    func didReceive(accountInfosByChainAssets _: [ChainAsset: AccountInfo?]) {
        record("accountInfos") { storedAccountInfoDeliveries += 1 }
    }

    func handleWalletChanged(wallet: MetaAccountModel) {
        record("walletChanged") { storedChangedWallets.append(wallet) }
    }

    func didReceive(chainSettings _: [ChainSettings]) {
        record("chainSettings")
    }

    func didAdoptStoredWalletSeed(result: Result<MetaAccountModel, Error>) {
        record("adoption") { storedAdoptions.append(result) }
    }
}

final class CovHAssetListFetchingStub: ChainAssetFetchingProtocol {
    var result: Result<[ChainAsset], Error> = .success([])
    private(set) var requests: [[ChainAssetsFetching.Filter]] = []

    func fetch(
        shouldUseCache _: Bool,
        filters: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        requests.append(filters)
        completionBlock(result)
    }

    func fetchAwaitOperation(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        let operation = BaseOperation<[ChainAsset]>()
        operation.result = result
        return operation
    }

    func fetchAwait(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset] {
        try result.get()
    }
}

final class CovHAssetListRegistryStub: ChainRegistryProtocol {
    private let lock = NSLock()
    private var storedRetries: [ChainModel.Id] = []
    var retries: [ChainModel.Id] {
        lock.lock()
        defer { lock.unlock() }
        return storedRetries
    }

    var availableChainIds: Set<ChainModel.Id>? { [] }
    var availableChains: [ChainModel] { [] }
    var chainsTypesMap: [String: Data] { [:] }
    func resetConnection(for _: ChainModel.Id) {}
    func retryConnection(for chainId: ChainModel.Id) {
        lock.lock()
        storedRetries.append(chainId)
        lock.unlock()
    }

    func getConnection(for _: ChainModel.Id) -> ChainConnection? { nil }
    func getEthereumConnection(for _: ChainModel.Id) -> Web3.Eth? { nil }
    func getTonApiClientFactory() throws -> TonAPIClientFactory { throw NSError(domain: "cov-h-asset-list", code: 1) }
    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { nil }
    func getChain(for _: ChainModel.Id) -> ChainModel? { nil }
    func chainsSubscribe(_: AnyObject, runningInQueue _: DispatchQueue, updateClosure _: @escaping ([DataProviderChange<ChainModel>]) -> Void) {}
    func chainsUnsubscribe(_: AnyObject) {}
    func syncUp() {}
    func performHotBoot() {}
    func performColdBoot() {}
    func subscribeToChains() {}
}

final class CovHAssetListRemoteStub: AccountInfoRemoteService, @unchecked Sendable {
    func fetchAccountInfos(for _: ChainModel, wallet _: MetaAccountModel) async throws -> [ChainAssetId: AccountInfo?] { [:] }
    func fetchAccountInfo(for _: ChainAsset, wallet _: MetaAccountModel) async throws -> AccountInfo? { nil }
}

final class CovHAssetListPricesSpy: PricesServiceProtocol {
    private(set) var setups = 0
    private(set) var updates = 0
    func setup() { setups += 1 }
    func updatePrices() { updates += 1 }
}

final class CovHAssetListAdopterStub: UniversalWalletStoredSeedAdopting {
    var error: Error?
    private(set) var requests: [MetaAccountModel] = []

    func adoptStoredSecret(for wallet: MetaAccountModel) throws -> MetaAccountModel {
        requests.append(wallet)
        if let error { throw error }
        return wallet
    }
}

final class CovHAssetListNetworkIssuesStub: NetworkIssuesCenterProtocol {
    private(set) var forced = 0
    func addIssuesListener(_: NetworkIssuesCenterListener, getExisting _: Bool) {}
    func removeIssuesListener(_: NetworkIssuesCenterListener) {}
    func forceNotify() { forced += 1 }
}

final class CovHAssetListMissingAccountsStub: MissingAccountFetcherProtocol {
    var chains: [ChainModel] = []
    func fetchMissingAccounts(for _: MetaAccountModel, complection: @escaping ([ChainModel]) -> Void) {
        complection(chains)
    }
}

final class CovHAssetListAccountInfoStub: AccountInfoFetchingProtocol {
    func fetch(for chainAsset: ChainAsset, accountId _: AccountId, completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void) {
        completionBlock(chainAsset, nil)
    }

    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel, completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void) {
        completionBlock([:])
    }

    func fetch(for chainAsset: ChainAsset, accountId _: AccountId) async throws -> (ChainAsset, AccountInfo?) { (chainAsset, nil) }
    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAsset: AccountInfo?] { [:] }
    func fetchByUniqKey(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAssetKey: AccountInfo?] { [:] }
}

/// The real interactor wired to in-memory stores and doubles. Catalog reads go through the module's own
/// dependency container; the tests filter them to a chain id no catalog has, so they deliver an empty list.
final class CovHAssetListInteractorHarness {
    let wallet: MetaAccountModel
    let eventCenter = EventCenter()
    let output = CovHAssetListOutputSpy()
    let fetching = CovHAssetListFetchingStub()
    let registry = CovHAssetListRegistryStub()
    let prices = CovHAssetListPricesSpy()
    let settings = InMemorySettingsManager()
    let missingAccounts = CovHAssetListMissingAccountsStub()
    let walletSettings: SelectedWalletSettings
    let interactor: ChainAssetListInteractor
    let unknownChainFilter: [ChainAssetsFetching.Filter] = [.chainId("cov-h-missing-\(UUID().uuidString)")]

    init(
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        missingChains: [ChainModel] = [],
        adopter: UniversalWalletStoredSeedAdopting = CovHAssetListAdopterStub(),
        walletSettings: SelectedWalletSettings? = nil
    ) {
        self.wallet = wallet
        missingAccounts.chains = missingChains
        let userFacade = UserDataStorageTestFacade()
        let queue = OperationQueue()
        self.walletSettings = walletSettings ?? SelectedWalletSettings(storageFacade: userFacade, operationQueue: queue)
        let accountInfoRepository = SubstrateRepositoryFactory(storageFacade: userFacade).createAccountInfoStorageItemRepository()
        let accountRepository = AccountRepositoryFactory(storageFacade: userFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        let issuesCenter = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: CovHAssetListNetworkIssuesStub(),
            eventCenter: eventCenter,
            missingAccountHelper: missingAccounts,
            accountInfoFetcher: CovHAssetListAccountInfoStub()
        )
        interactor = ChainAssetListInteractor(
            wallet: wallet,
            eventCenter: eventCenter,
            accountRepository: AnyDataProviderRepository(accountRepository),
            accountInfoFetchingProvider: AccountInfoFetching(
                accountInfoRepository: accountInfoRepository,
                chainRegistry: registry,
                operationQueue: queue
            ),
            dependencyContainer: ChainAssetListDependencyContainer(),
            ethRemoteBalanceFetching: EthereumRemoteBalanceFetching(
                chainRegistry: registry,
                repositoryWrapper: BalanceRepositoryCacheWrapper(
                    logger: Logger.shared,
                    repository: accountInfoRepository,
                    operationManager: OperationManager()
                )
            ),
            chainAssetFetching: fetching,
            userDefaultsStorage: settings,
            chainsIssuesCenter: issuesCenter,
            chainSettingsRepository: AsyncAnyRepository(
                ChainSettingsRepositoryFactory(storageFacade: userFacade).createAsyncRepository()
            ),
            chainRegistry: registry,
            accountInfoRemoteService: CovHAssetListRemoteStub(),
            pricesService: prices,
            operationQueue: queue,
            storedSeedAdopter: adopter,
            walletSettings: self.walletSettings
        )
    }

    /// Loads the (empty) catalog and waits until the list and its balances arrived.
    func loadEmptyCatalog() {
        interactor.updateChainAssets(using: unknownChainFilter, sorts: [], useCashe: false)
        CovHAssetListFixture.spin(timeout: 10) { output.accountInfoDeliveries > 0 }
    }
}

// MARK: - Presenter doubles

final class CovHAssetListViewSpy: UIViewController, ChainAssetListViewInput {
    private(set) var models: [ChainAssetListViewModel] = []
    private(set) var bannerReloads = 0
    func didReceive(viewModel: ChainAssetListViewModel) { models.append(viewModel) }
    func reloadBanners() { bannerReloads += 1 }
}

final class CovHAssetListInteractorSpy: ChainAssetListInteractorInput {
    var shouldRunManageAssetAnimate = true
    private(set) var calls: [String] = []
    private(set) var hidden: [AssetKey] = []
    private(set) var shown: [AssetKey] = []
    private(set) var unused: [ChainModel.Id] = []
    private(set) var retried: [ChainModel.Id] = []
    private(set) var catalogFilters: [[ChainAssetsFetching.Filter]] = []

    func setup(with _: ChainAssetListInteractorOutput) { calls.append("setup") }
    func updateChainAssets(using filters: [ChainAssetsFetching.Filter], sorts _: [ChainAssetsFetching.SortDescriptor], useCashe _: Bool) {
        calls.append("update")
        catalogFilters.append(filters)
    }

    func markUnused(chain: ChainModel) { unused.append(chain.chainId) }
    func reload() { calls.append("reload") }
    func getAvailableChainAssets(chainAsset _: ChainAsset, completion: @escaping (([ChainAsset]) -> Void)) { completion([]) }
    func hideChainAsset(_ chainAsset: ChainAsset) { hidden.append(chainAsset.assetKey) }
    func showChainAsset(_ chainAsset: ChainAsset) { shown.append(chainAsset.assetKey) }
    func retryConnection(for chainId: ChainModel.Id) { retried.append(chainId) }
    func adoptStoredWalletSeed() { calls.append("adopt") }
}

final class CovHAssetListRouterSpy: ChainAssetListRouterInput {
    private(set) var calls: [String] = []
    private(set) var sheets: [SheetAlertPresentableViewModel] = []
    private(set) var accountOptions: [[SheetAlertPresentableAction]] = []
    private(set) var errors: [Error] = []
    private(set) var warningHandlers: [WarningAlertButtonHandler] = []
    private(set) var chainModels: [UniqueChainModel] = []
    private(set) var assets: [AssetKey] = []
    private(set) var manageFilters: [ManageAssetsFilter] = []

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return true
    }

    func presentWarningAlert(from _: ControllerBackedProtocol?, config _: WarningAlertConfig, buttonHandler: @escaping WarningAlertButtonHandler) {
        calls.append("warning")
        warningHandlers.append(buttonHandler)
    }

    func showAppstoreUpdatePage() { calls.append("appstore") }
    func showAssetNetworks(from _: ControllerBackedProtocol?, chainAsset _: ChainAsset) { calls.append("networks") }
    func showChainAccount(from _: ControllerBackedProtocol?, chainAsset: ChainAsset) {
        calls.append("chainAccount")
        assets.append(chainAsset.assetKey)
    }

    func showSendFlow(from _: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet _: MetaAccountModel) {
        calls.append("send")
        assets.append(chainAsset.assetKey)
    }

    func showReceiveFlow(from _: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet _: MetaAccountModel) {
        calls.append("receive")
        assets.append(chainAsset.assetKey)
    }

    func presentAccountOptions(from _: ControllerBackedProtocol?, locale _: Locale?, actions: [SheetAlertPresentableAction]) {
        accountOptions.append(actions)
    }

    func showCreate(uniqueChainModel: UniqueChainModel, from _: ControllerBackedProtocol?) {
        calls.append("create")
        chainModels.append(uniqueChainModel)
    }

    func showImport(uniqueChainModel: UniqueChainModel, from _: ControllerBackedProtocol?) {
        calls.append("import")
        chainModels.append(uniqueChainModel)
    }

    func showManageAsset(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        filter _: NetworkManagmentFilter?,
        visibilityFilter: ManageAssetsFilter
    ) {
        calls.append("manage")
        manageFilters.append(visibilityFilter)
    }

    func showIssueNotification(from _: ControllerBackedProtocol?, issues _: [ChainIssue], wallet _: MetaAccountModel) {
        calls.append("issues")
    }

    func showWalletManagment(from _: ControllerBackedProtocol?) { calls.append("wallets") }
    func dismiss(view _: ControllerBackedProtocol?) { calls.append("dismiss") }
}

/// Records what a view controller presents instead of presenting it.
final class CovHAssetListPresentingHost: UIViewController, ChainAssetListViewInput {
    private(set) var presented: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presented.append(viewControllerToPresent)
        completion?()
    }

    func didReceive(viewModel _: ChainAssetListViewModel) {}
    func reloadBanners() {}
}

/// Records pushes and presentations of a navigation stack.
final class CovHAssetListNavigationSpy: UINavigationController {
    private(set) var pushed: [UIViewController] = []
    private(set) var presentedControllers: [UIViewController] = []

    override func pushViewController(_ viewController: UIViewController, animated _: Bool) {
        // `init(rootViewController:)` installs the root through a push; keep it so the host has a navigation controller.
        guard !viewControllers.isEmpty else {
            super.pushViewController(viewController, animated: false)
            return
        }
        pushed.append(viewController)
    }

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
        completion?()
    }
}
