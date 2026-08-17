import Foundation
import RobinHood
import SSFModels
import SoraKeystore
import UIKit

struct DailyAssetDiscoveryScheduler {
    static let defaultInterval: TimeInterval = 24 * 60 * 60
    static let defaultMaximumNetworks = 24

    private let userDefaults: UserDefaults
    private let interval: TimeInterval
    private let maximumNetworks: Int

    init(
        userDefaults: UserDefaults = .standard,
        interval: TimeInterval = Self.defaultInterval,
        maximumNetworks: Int = Self.defaultMaximumNetworks
    ) {
        self.userDefaults = userDefaults
        self.interval = interval
        self.maximumNetworks = maximumNetworks
    }

    func isDue(walletId: MetaAccountId, now: Date = Date()) -> Bool {
        guard let lastAttempt = userDefaults.object(forKey: key(walletId)) as? Date else {
            return true
        }

        return now.timeIntervalSince(lastAttempt) >= interval
    }

    func markAttempt(walletId: MetaAccountId, now: Date = Date()) {
        userDefaults.set(now, forKey: key(walletId))
    }

    func clearAttempt(walletId: MetaAccountId) {
        userDefaults.removeObject(forKey: key(walletId))
    }

    func eligibleChains(
        from chains: [ChainModel],
        wallet: MetaAccountModel,
        includeTestnets: Bool = false
    ) -> [ChainModel] {
        guard maximumNetworks > 0 else {
            return []
        }

        let candidates = chains
            .filter { chain in
                (includeTestnets || !chain.isTestnet) &&
                    wallet.fetch(for: chain.accountRequest()) != nil
            }
            .sorted { $0.chainId < $1.chainId }
            .uniq(predicate: { $0.chainId })

        guard candidates.isNotEmpty else {
            return []
        }

        let cursor = userDefaults.integer(forKey: cursorKey(wallet.metaId)) % candidates.count
        let ordered = Array(candidates[cursor...]) + Array(candidates[..<cursor])
        let selected = Array(ordered.prefix(maximumNetworks))

        // A bounded sweep must eventually visit every eligible network. Persist the
        // next starting point per wallet instead of repeatedly scanning the first 24.
        let nextCursor = (cursor + selected.count) % candidates.count
        userDefaults.set(nextCursor, forKey: cursorKey(wallet.metaId))

        return selected
    }

    private func key(_ walletId: MetaAccountId) -> String {
        ["portfolio.discovery.daily.last_attempt", walletId].joined(separator: ":")
    }

    private func cursorKey(_ walletId: MetaAccountId) -> String {
        ["portfolio.discovery.daily.cursor", walletId].joined(separator: ":")
    }
}

struct AssetDiscoveryChainCatalog {
    let chains: [ChainModel]
    let isComplete: Bool

    var chainAssets: [ChainAsset] {
        chains.flatMap(\.chainAssets)
    }

    func productionChains(
        wallet: MetaAccountModel,
        optedInTestnetIds: Set<ChainModel.Id> = []
    ) -> [ChainModel] {
        chains
            .filter { chain in
                (!chain.isTestnet || optedInTestnetIds.contains(chain.chainId)) &&
                    wallet.fetch(for: chain.accountRequest()) != nil
            }
            .uniq(predicate: { $0.chainId })
    }
}

protocol AssetDiscoveryChainCatalogProviding {
    /// Returns every persisted registry row, including disabled networks.
    /// A successful unfiltered repository read is a complete migration snapshot;
    /// presentation/network activation is deliberately not an input.
    func fetchCatalog() async throws -> AssetDiscoveryChainCatalog
}

final class RepositoryAssetDiscoveryChainCatalog: AssetDiscoveryChainCatalogProviding {
    private let chainRepository: AsyncAnyRepository<ChainModel>

    init(
        chainRepository: AsyncAnyRepository<ChainModel> = AsyncAnyRepository(
            ChainRepositoryFactory().createAsyncRepository()
        )
    ) {
        self.chainRepository = chainRepository
    }

    func fetchCatalog() async throws -> AssetDiscoveryChainCatalog {
        let chains = try await chainRepository.fetchAll()
        return AssetDiscoveryChainCatalog(
            chains: chains.uniq(predicate: { $0.chainId }),
            isComplete: true
        )
    }
}

private enum AssetDiscoveryChainCatalogError: Error {
    case incomplete
}

enum AssetDiscoveryTrigger: String, Equatable {
    case walletCreatedOrImported
    case accountAdded
    case registryUpdated
    case pullToRefresh
    case dailySweep
}

struct AssetDiscoveryScanResult {
    let trigger: AssetDiscoveryTrigger
    let accountInfosByChain: [ChainModel: [ChainAssetId: AccountInfo?]]
    let failedChainIds: Set<ChainModel.Id>
}

/// Discovery owns background balance/catalog scans. Its contract deliberately
/// has no search, selected-network, visibility, or feature-activation input, so
/// presentation state cannot suppress synchronization.
protocol AssetDiscoveryService {
    func scan(
        wallet: MetaAccountModel,
        chains: [ChainModel],
        includeTestnets: Bool,
        trigger: AssetDiscoveryTrigger
    ) async -> AssetDiscoveryScanResult
}

final class AssetDiscoveryServiceAdapter: AssetDiscoveryService {
    private let accountInfoRemote: AccountInfoRemoteService
    private let userDefaults: UserDefaults

    init(
        accountInfoRemote: AccountInfoRemoteService,
        userDefaults: UserDefaults = .standard
    ) {
        self.accountInfoRemote = accountInfoRemote
        self.userDefaults = userDefaults
    }

    func scan(
        wallet: MetaAccountModel,
        chains: [ChainModel],
        includeTestnets: Bool,
        trigger: AssetDiscoveryTrigger
    ) async -> AssetDiscoveryScanResult {
        let chains = chains
            .filter { (includeTestnets || !$0.isTestnet) && wallet.fetch(for: $0.accountRequest()) != nil }
            .uniq(predicate: { $0.chainId })

        let responses = await withTaskGroup(
            of: (ChainModel, Result<[ChainAssetId: AccountInfo?], Error>).self,
            returning: [(ChainModel, Result<[ChainAssetId: AccountInfo?], Error>)].self
        ) { group in
            chains.forEach { chain in
                group.addTask {
                    NetworkScanStateStore.markAttempt(
                        for: chain,
                        walletId: wallet.metaId,
                        userDefaults: self.userDefaults
                    )
                    do {
                        let values = try await self.accountInfoRemote.fetchAccountInfos(
                            for: chain,
                            wallet: wallet
                        )
                        NetworkScanStateStore.markSuccess(
                            for: chain,
                            walletId: wallet.metaId,
                            userDefaults: self.userDefaults
                        )
                        return (chain, .success(values))
                    } catch {
                        NetworkScanStateStore.markFailure(
                            for: chain,
                            walletId: wallet.metaId,
                            userDefaults: self.userDefaults
                        )
                        return (chain, .failure(error))
                    }
                }
            }

            var values: [(ChainModel, Result<[ChainAssetId: AccountInfo?], Error>)] = []
            for await value in group {
                values.append(value)
            }
            return values
        }

        var accountInfosByChain = [ChainModel: [ChainAssetId: AccountInfo?]]()
        var failedChainIds = Set<ChainModel.Id>()
        responses.forEach { chain, result in
            switch result {
            case let .success(accountInfos):
                accountInfosByChain[chain] = accountInfos
            case .failure:
                failedChainIds.insert(chain.chainId)
                if let lastKnownProvider = accountInfoRemote as? AccountInfoLastKnownBalanceProviding {
                    let retained = lastKnownProvider.lastKnownAccountInfos(
                        for: chain,
                        wallet: wallet
                    )
                    if retained.isNotEmpty {
                        accountInfosByChain[chain] = retained
                    }
                }
            }
        }
        return AssetDiscoveryScanResult(
            trigger: trigger,
            accountInfosByChain: accountInfosByChain,
            failedChainIds: failedChainIds
        )
    }
}

protocol WalletAssetsObserver: ApplicationServiceProtocol {
    func update(wallet: MetaAccountModel)
    func updateVisibility(
        wallet: MetaAccountModel?,
        chainAssets: [ChainAsset]
    ) async -> MetaAccountModel
}

final class WalletAssetsObserverImpl: WalletAssetsObserver {
    private var wallet: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol
    private let eventCenter: EventCenterProtocol
    private let assetDiscoveryService: AssetDiscoveryService
    private let logger: LoggerProtocol
    private let userDefaultsStorage: SettingsManagerProtocol
    private let dailyDiscoveryScheduler: DailyAssetDiscoveryScheduler
    private let chainCatalog: AssetDiscoveryChainCatalogProviding
    private var foregroundObserver: NSObjectProtocol?

    private lazy var walletAssetsObserverQueue: DispatchQueue = {
        DispatchQueue(label: "co.jp.soramitsu.asset.observer.deliveryQueue")
    }()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        assetDiscoveryService: AssetDiscoveryService,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol,
        userDefaultsStorage: SettingsManagerProtocol,
        chainCatalog: AssetDiscoveryChainCatalogProviding = RepositoryAssetDiscoveryChainCatalog(),
        dailyDiscoveryScheduler: DailyAssetDiscoveryScheduler = DailyAssetDiscoveryScheduler()
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.assetDiscoveryService = assetDiscoveryService
        self.eventCenter = eventCenter
        self.logger = logger
        self.userDefaultsStorage = userDefaultsStorage
        self.chainCatalog = chainCatalog
        self.dailyDiscoveryScheduler = dailyDiscoveryScheduler
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    // MARK: - WalletAssetsObserver

    func update(wallet: MetaAccountModel) {
        throttle()
        checkNewAccounts(for: wallet)
        self.wallet = wallet
        setup()
    }

    func updateVisibility(
        wallet: MetaAccountModel?,
        chainAssets: [ChainAsset]
    ) async -> MetaAccountModel {
        if let wallet {
            self.wallet = wallet
        }
        let requestedChains = chainAssets
            .map { $0.chain }
            .uniq(predicate: { $0.chainId })
        let optedInTestnetIds = Set(
            requestedChains.filter(\.isTestnet).map(\.chainId)
        )
        let chains: [ChainModel]
        do {
            let catalog = try await loadCompleteCatalog()
            chains = catalog.productionChains(
                wallet: self.wallet,
                optedInTestnetIds: optedInTestnetIds
            )
        } catch {
            logger.error("Asset discovery catalog fetch failed: \(error.localizedDescription)")
            // Preserve manual refresh for the requested rows when the complete
            // repository snapshot is temporarily unavailable. The incomplete
            // fallback never commits the irreversible hide migration marker.
            chains = requestedChains
        }
        let updatedWallet = await updateVisibility(
            for: chains,
            includeTestnets: optedInTestnetIds.isNotEmpty,
            trigger: .pullToRefresh
        )
        return updatedWallet
    }

    // MARK: - ApplicationServiceProtocol

    func setup() {
        eventCenter.add(observer: self)
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: walletAssetsObserverQueue
        ) { [weak self] changes in
            self?.handleChains(changes: changes, accounts: nil)
        }
        if foregroundObserver == nil {
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.triggerDailySweepIfDue()
            }
        }
        if !triggerInitialDiscoveryIfNeeded() {
            triggerDailySweepIfDue()
        }
    }

    func throttle() {
        chainRegistry.chainsUnsubscribe(self)
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
            self.foregroundObserver = nil
        }
    }

    // MARK: - Private methods

    private func handleChains(changes: [DataProviderChange<ChainModel>], accounts: [ChainAccountModel]?) {
        Task {
            let changedChains = changes.filter {
                switch $0 {
                case .insert, .update:
                    return true
                default:
                    return false
                }
            }.compactMap { $0.item }
            let catalogChains: [ChainModel]
            do {
                let catalog = try await loadCompleteCatalog()
                let catalogById = Dictionary(
                    uniqueKeysWithValues: catalog.chains.map { ($0.chainId, $0) }
                )
                // Prefer the complete persisted model, while retaining an event
                // row if notification delivery races the repository snapshot.
                catalogChains = changedChains.map { catalogById[$0.chainId] ?? $0 }
            } catch {
                logger.error("Asset discovery catalog fetch failed: \(error.localizedDescription)")
                catalogChains = changedChains
            }

            var chains = catalogChains.filter {
                !$0.isTestnet && wallet.fetch(for: $0.accountRequest()) != nil
            }
            if let accounts, accounts.isNotEmpty {
                chains = chains.filter { chain in
                    accounts.contains {
                        UniversalWalletChainAccountSupport.chainId(
                            $0.chainId,
                            matches: chain.accountRequest().chainId
                        )
                    }
                }
            }

            _ = await updateVisibility(for: chains, trigger: .registryUpdated)
            performSaveAndNotify()
        }
    }

    private func triggerDailySweepIfDue(now: Date = Date()) {
        guard dailyDiscoveryScheduler.isDue(walletId: wallet.metaId, now: now) else {
            return
        }

        dailyDiscoveryScheduler.markAttempt(walletId: wallet.metaId, now: now)

        Task {
            do {
                let catalog = try await loadCompleteCatalog()
                let chains = dailyDiscoveryScheduler.eligibleChains(
                    from: catalog.chains,
                    wallet: wallet
                )
                guard chains.isNotEmpty else {
                    return
                }
                _ = await updateVisibility(for: chains, trigger: .dailySweep)
                performSaveAndNotify()
            } catch {
                dailyDiscoveryScheduler.clearAttempt(walletId: wallet.metaId)
                logger.error("Asset discovery catalog fetch failed: \(error.localizedDescription)")
            }
        }
    }

    private func updateVisibility(
        for chains: [ChainModel],
        includeTestnets: Bool = false,
        trigger: AssetDiscoveryTrigger
    ) async -> MetaAccountModel {
        let result = await assetDiscoveryService.scan(
            wallet: wallet,
            chains: chains,
            includeTestnets: includeTestnets,
            trigger: trigger
        )
        updateCurrentWallet(with: result.accountInfosByChain)
        return wallet
    }

    @discardableResult
    private func triggerInitialDiscoveryIfNeeded() -> Bool {
        let key = ["portfolio.discovery.initial", wallet.metaId].joined(separator: ":")
        guard !UserDefaults.standard.bool(forKey: key) else {
            return false
        }
        UserDefaults.standard.set(true, forKey: key)
        Task {
            do {
                let catalog = try await loadCompleteCatalog()
                let chains = catalog.productionChains(wallet: wallet)
                guard chains.isNotEmpty else {
                    // Registry updates will perform the initial scan once rows arrive.
                    UserDefaults.standard.removeObject(forKey: key)
                    return
                }
                _ = await updateVisibility(for: chains, trigger: .walletCreatedOrImported)
                performSaveAndNotify()
            } catch {
                UserDefaults.standard.removeObject(forKey: key)
                logger.error("Asset discovery catalog fetch failed: \(error.localizedDescription)")
            }
        }
        return true
    }

    private func checkNewAccounts(for wallet: MetaAccountModel) {
        let newAccounts = wallet.chainAccounts.subtracting(self.wallet.chainAccounts)
        self.wallet = wallet
        guard newAccounts.isNotEmpty else {
            return
        }
        scanAccountInfo(for: Array(newAccounts))
    }

    private func scanAccountInfo(for accounts: [ChainAccountModel]) {
        Task {
            do {
                let catalog = try await loadCompleteCatalog()
                let chains = catalog.productionChains(wallet: wallet).filter { chain in
                    accounts.contains {
                        UniversalWalletChainAccountSupport.chainId(
                            $0.chainId,
                            matches: chain.accountRequest().chainId
                        )
                    }
                }
                _ = await updateVisibility(for: chains, trigger: .accountAdded)
                performSaveAndNotify()
            } catch {
                logger.error("Asset discovery catalog fetch failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadCompleteCatalog() async throws -> AssetDiscoveryChainCatalog {
        let catalog = try await chainCatalog.fetchCatalog()
        guard catalog.isComplete else {
            throw AssetDiscoveryChainCatalogError.incomplete
        }
        AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: catalog.chainAssets,
            catalogIsComplete: true
        )
        return catalog
    }

    private func emptyAccountInfos(for chain: ChainModel) -> [ChainAssetId: AccountInfo?] {
        let mapped: [(ChainAssetId, AccountInfo?)] = chain
            .chainAssets
            .map { ($0.chainAssetId, nil) }
            .uniq(predicate: { $0.0 })
        return Dictionary(uniqueKeysWithValues: mapped)
    }

    private func performSaveAndNotify() {
        SelectedWalletSettings.shared.performSave(value: wallet) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case let .success(wallet):
                let event = MetaAccountModelChangedEvent(account: wallet)
                self.eventCenter.notify(with: event)
                self.markAsMigrated(wallet)
            case let .failure(failure):
                self.logger.customError(failure)
            }
        }
    }

    private func updateCurrentWallet(
        with resultMap: [ChainModel: [ChainAssetId: AccountInfo?]]
    ) {
        // Scans update balances, not presentation intent. In particular, a
        // positive unverified holding must remain `.auto` in Detected assets
        // until the user explicitly chooses Show or Hide.
        let chains = resultMap.keys.map { $0 }
        setDefaultVisibilitiesIfNeeded(chains: chains)
    }

    private func setDefaultVisibilitiesIfNeeded(chains: [ChainModel]) {
        let chainAssets: [ChainAsset] = chains
            .map { $0.chainAssets }
            .reduce([], +)
        chainAssets.forEach { chainAsset in
            let isPinnedNative = chainAsset.chain.rank != nil && chainAsset.asset.isUtility
            let isSoraNexusXor = chainAsset.asset.isUtility
                && chainAsset.asset.symbol.caseInsensitiveCompare("XOR") == .orderedSame
                && chainAsset.chain.name.lowercased().contains("sora")
                && chainAsset.chain.name.lowercased().contains("nexus")

            guard isPinnedNative || isSoraNexusXor,
                  AssetVisibilityPreferenceStore.preference(
                      walletId: wallet.metaId,
                      assetKey: chainAsset.assetKey
                  ) == .auto else {
                return
            }

            AssetVisibilityPreferenceStore.setPreference(
                .shown,
                walletId: wallet.metaId,
                assetKey: chainAsset.assetKey
            )
        }
    }

    private func markAsMigrated(_ wallet: MetaAccountModel) {
        let isFirstRunKey = createKeyForMigrated(wallet: wallet)
        userDefaultsStorage.set(value: true, for: isFirstRunKey)
    }

    private func createKeyForMigrated(
        wallet: MetaAccountModel
    ) -> String {
        [
            "asset.management.should.migrate.wallet",
            wallet.metaId
        ].joined(separator: ":")
    }
}

enum AssetPreference: String, Codable {
    case auto
    case shown
    case hidden
}

struct AssetVisibilityPreferenceChangedEvent: EventProtocol, Equatable {
    let walletId: MetaAccountId
    let assetKey: AssetKey
    let preference: AssetPreference

    func accept(visitor: EventVisitorProtocol) {
        visitor.processAssetVisibilityPreferenceChanged(event: self)
    }
}

enum AssetVisibilityPreferenceStore {
    private static let prefix = "asset.presentation.explicit.hidden"
    private static let migrationPrefix = "asset.presentation.asset_key.migrated"
    private static let migrationLock = NSLock()

    static func setExplicitlyHidden(
        _ hidden: Bool,
        walletId: String,
        chainAsset: ChainAsset,
        userDefaults: UserDefaults = .standard
    ) {
        setPreference(
            hidden ? .hidden : .shown,
            walletId: walletId,
            assetKey: chainAsset.assetKey,
            userDefaults: userDefaults
        )
    }

    static func isExplicitlyHidden(
        walletId: String,
        chainAsset: ChainAsset,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        preference(
            walletId: walletId,
            assetKey: chainAsset.assetKey,
            userDefaults: userDefaults
        ) == .hidden
    }

    static func isSelectable(
        walletId: String,
        chainAsset: ChainAsset,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        switch preference(
            walletId: walletId,
            assetKey: chainAsset.assetKey,
            userDefaults: userDefaults
        ) {
        case .hidden:
            return false
        case .shown:
            return true
        case .auto:
            return AssetTrustResolver.metadataTrust(
                for: chainAsset,
                userDefaults: userDefaults
            ).trust == .verified
        }
    }

    static func setExplicitlyHidden(
        _ hidden: Bool,
        walletId: String,
        assetId: String,
        userDefaults: UserDefaults = .standard
    ) {
        setPreference(
            hidden ? .hidden : .shown,
            walletId: walletId,
            assetId: assetId,
            userDefaults: userDefaults
        )
    }

    static func isExplicitlyHidden(
        walletId: String,
        assetId: String,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        preference(walletId: walletId, assetId: assetId, userDefaults: userDefaults) == .hidden
    }

    static func setPreference(
        _ preference: AssetPreference,
        walletId: String,
        assetId: String,
        userDefaults: UserDefaults = .standard
    ) {
        let storageKey = key(walletId: walletId, assetId: assetId)
        if preference == .auto {
            userDefaults.removeObject(forKey: storageKey)
        } else {
            userDefaults.set(preference.rawValue, forKey: storageKey)
        }
    }

    static func setPreference(
        _ preference: AssetPreference,
        walletId: String,
        assetKey: AssetKey,
        userDefaults: UserDefaults = .standard
    ) {
        let storageKey = key(walletId: walletId, assetKey: assetKey)
        if preference == .auto {
            userDefaults.removeObject(forKey: storageKey)
        } else {
            userDefaults.set(preference.rawValue, forKey: storageKey)
        }
    }

    static func preference(
        walletId: String,
        assetId: String,
        userDefaults: UserDefaults = .standard
    ) -> AssetPreference {
        let storageKey = key(walletId: walletId, assetId: assetId)
        if let rawValue = userDefaults.string(forKey: storageKey),
           let preference = AssetPreference(rawValue: rawValue) {
            return preference
        }

        // Migrate the previous boolean tombstone in place.
        if let legacyValue = userDefaults.object(forKey: storageKey) as? Bool {
            let preference: AssetPreference = legacyValue ? .hidden : .shown
            userDefaults.set(preference.rawValue, forKey: storageKey)
            return preference
        }

        return .auto
    }

    static func preference(
        walletId: String,
        assetKey: AssetKey,
        userDefaults: UserDefaults = .standard
    ) -> AssetPreference {
        let storageKey = key(walletId: walletId, assetKey: assetKey)
        if let rawValue = userDefaults.string(forKey: storageKey),
           let preference = AssetPreference(rawValue: rawValue) {
            return preference
        }

        return .auto
    }

    static func migrateLegacyHides(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        catalogIsComplete: Bool,
        userDefaults: UserDefaults = .standard
    ) {
        guard catalogIsComplete else {
            return
        }

        migrationLock.lock()
        defer { migrationLock.unlock() }

        let migrationKey = [migrationPrefix, wallet.metaId].joined(separator: ":")
        guard !userDefaults.bool(forKey: migrationKey) else {
            return
        }

        wallet.assetsVisibility.forEach { visibility in
            // Take one immutable snapshot of every canonical asset represented
            // by the legacy row/group. Once the marker below is written, assets
            // discovered later never consult the legacy identifier again.
            let candidates = chainAssets.filter {
                $0.identifier == visibility.assetId ||
                    $0.asset.id.caseInsensitiveCompare(visibility.assetId) == .orderedSame ||
                    $0.asset.canonicalAssetId.caseInsensitiveCompare(visibility.assetId) == .orderedSame ||
                    $0.asset.symbol.caseInsensitiveCompare(visibility.assetId) == .orderedSame ||
                    $0.asset.name.caseInsensitiveCompare(visibility.assetId) == .orderedSame
            }

            Dictionary(grouping: candidates, by: \.assetKey)
                .compactMapValues(\.first)
                .values
                .forEach {
                    setPreference(
                        visibility.hidden ? .hidden : .shown,
                        walletId: wallet.metaId,
                        assetKey: $0.assetKey,
                        userDefaults: userDefaults
                    )
                }
        }
        userDefaults.set(true, forKey: migrationKey)
    }

    private static func key(walletId: String, assetId: String) -> String {
        [prefix, walletId, assetId].joined(separator: ":")
    }

    private static func key(walletId: String, assetKey: AssetKey) -> String {
        [
            prefix,
            walletId,
            assetKey.ecosystem,
            assetKey.chainId,
            assetKey.assetId
        ].joined(separator: ":")
    }
}

extension WalletAssetsObserverImpl: EventVisitorProtocol {
    func processChainSyncDidComplete(event: ChainSyncDidComplete) {
        // Chain sync events contain disabled rows that the live ChainRegistry
        // deliberately does not activate. Feed those rows into discovery
        // without changing their activation state.
        handleChains(
            changes: event.newOrUpdatedChains.map { .update(newItem: $0) },
            accounts: nil
        )
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        wallet = event.account
    }
}
