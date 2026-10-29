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
            case let .failure(error):
                failedChainIds.insert(chain.chainId)
                if let incomplete = error as? IncompleteAccountInfosError, incomplete.accountInfos.isNotEmpty {
                    // The scan failed, but the balances it read are fresh.
                    accountInfosByChain[chain] = incomplete.accountInfos
                } else if let lastKnownProvider = accountInfoRemote as? AccountInfoLastKnownBalanceProviding {
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
        let targetWallet = self.wallet
        let requestedChains = chainAssets
            .map { $0.chain }
            .uniq(predicate: { $0.chainId })
        let optedInTestnetIds = Set(
            requestedChains.filter(\.isTestnet).map(\.chainId)
        )
        let chains: [ChainModel]
        do {
            let catalog = try await loadCompleteCatalog(wallet: targetWallet)
            chains = catalog.productionChains(
                wallet: targetWallet,
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
            wallet: targetWallet,
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
        let targetWallet = wallet
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
                let catalog = try await loadCompleteCatalog(wallet: targetWallet)
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
                !$0.isTestnet && targetWallet.fetch(for: $0.accountRequest()) != nil
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

            let scannedWallet = await updateVisibility(
                for: chains,
                wallet: targetWallet,
                trigger: .registryUpdated
            )
            finishDiscovery(wallet: scannedWallet)
        }
    }

    private func triggerDailySweepIfDue(now: Date = Date()) {
        let targetWallet = wallet
        guard dailyDiscoveryScheduler.isDue(walletId: targetWallet.metaId, now: now) else {
            return
        }

        dailyDiscoveryScheduler.markAttempt(walletId: targetWallet.metaId, now: now)

        Task {
            do {
                let catalog = try await loadCompleteCatalog(wallet: targetWallet)
                let chains = dailyDiscoveryScheduler.eligibleChains(
                    from: catalog.chains,
                    wallet: targetWallet
                )
                guard chains.isNotEmpty else {
                    return
                }
                let scannedWallet = await updateVisibility(
                    for: chains,
                    wallet: targetWallet,
                    trigger: .dailySweep
                )
                finishDiscovery(wallet: scannedWallet)
            } catch {
                dailyDiscoveryScheduler.clearAttempt(walletId: targetWallet.metaId)
                logger.error("Asset discovery catalog fetch failed: \(error.localizedDescription)")
            }
        }
    }

    private func updateVisibility(
        for chains: [ChainModel],
        wallet scannedWallet: MetaAccountModel,
        includeTestnets: Bool = false,
        trigger: AssetDiscoveryTrigger
    ) async -> MetaAccountModel {
        // Scans update balances, not presentation intent: zero rows follow
        // PortfolioVisibilityPolicy, and a positive unverified holding stays
        // `.auto` in Detected assets until the user chooses Show or Hide.
        _ = await assetDiscoveryService.scan(
            wallet: scannedWallet,
            chains: chains,
            includeTestnets: includeTestnets,
            trigger: trigger
        )
        return scannedWallet
    }

    @discardableResult
    private func triggerInitialDiscoveryIfNeeded() -> Bool {
        let targetWallet = wallet
        let key = ["portfolio.discovery.initial", targetWallet.metaId].joined(separator: ":")
        guard !UserDefaults.standard.bool(forKey: key) else {
            return false
        }
        UserDefaults.standard.set(true, forKey: key)
        Task {
            do {
                let catalog = try await loadCompleteCatalog(wallet: targetWallet)
                let chains = catalog.productionChains(wallet: targetWallet)
                guard chains.isNotEmpty else {
                    // Registry updates will perform the initial scan once rows arrive.
                    UserDefaults.standard.removeObject(forKey: key)
                    return
                }
                let scannedWallet = await updateVisibility(
                    for: chains,
                    wallet: targetWallet,
                    trigger: .walletCreatedOrImported
                )
                finishDiscovery(wallet: scannedWallet)
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
        scanAccountInfo(for: Array(newAccounts), wallet: wallet)
    }

    private func scanAccountInfo(
        for accounts: [ChainAccountModel],
        wallet targetWallet: MetaAccountModel
    ) {
        Task {
            do {
                let catalog = try await loadCompleteCatalog(wallet: targetWallet)
                let chains = catalog.productionChains(wallet: targetWallet).filter { chain in
                    accounts.contains {
                        UniversalWalletChainAccountSupport.chainId(
                            $0.chainId,
                            matches: chain.accountRequest().chainId
                        )
                    }
                }
                let scannedWallet = await updateVisibility(
                    for: chains,
                    wallet: targetWallet,
                    trigger: .accountAdded
                )
                finishDiscovery(wallet: scannedWallet)
            } catch {
                logger.error("Asset discovery catalog fetch failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadCompleteCatalog(wallet: MetaAccountModel) async throws -> AssetDiscoveryChainCatalog {
        let catalog = try await chainCatalog.fetchCatalog()
        guard catalog.isComplete else {
            throw AssetDiscoveryChainCatalogError.incomplete
        }
        // Bitcoin and Taira are persisted with the registry rows; naming them
        // here keeps the one-time migration complete if that write is pending.
        let appOwnedChainAssets = UniversalWalletRegistry.appOwnedProductionChains.flatMap(\.chainAssets)
        let migratedAssetKeys = AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: (catalog.chainAssets + appOwnedChainAssets).uniq(predicate: { $0.chainAssetId }),
            catalogIsComplete: true
        )
        if let assetKey = migratedAssetKeys.first {
            // The portfolio rebuilds every row from the store, so one event
            // per wallet refreshes it.
            eventCenter.notify(
                with: AssetVisibilityPreferenceChangedEvent(
                    walletId: wallet.metaId,
                    assetKey: assetKey,
                    preference: AssetVisibilityPreferenceStore.preference(
                        walletId: wallet.metaId,
                        assetKey: assetKey
                    )
                )
            )
        }
        return catalog
    }

    private func emptyAccountInfos(for chain: ChainModel) -> [ChainAssetId: AccountInfo?] {
        let mapped: [(ChainAssetId, AccountInfo?)] = chain
            .chainAssets
            .map { ($0.chainAssetId, nil) }
            .uniq(predicate: { $0.0 })
        return Dictionary(uniqueKeysWithValues: mapped)
    }

    private func finishDiscovery(wallet: MetaAccountModel) {
        // Discovery only updates remote balance caches. Re-saving its captured
        // wallet can overwrite a newer account migration (notably the
        // asynchronously provisioned BTC key).
        markAsMigrated(wallet)
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
    /// Marker of the first AssetKey migration (TestFlight 2026.9.x builds).
    private static let migrationPrefix = "asset.presentation.asset_key.migrated"
    private static let migrationV2Prefix = "asset.presentation.asset_key.migrated.v2"
    /// Assets App Store 4.0.4 hid automatically while they held nothing.
    private static let legacyZeroHiddenPrefix = "asset.presentation.legacy_zero_hidden"
    /// Explicit Hidden preferences carried over from 4.0.4 TON wallets, so the
    /// portfolio can say "Hidden in previous version".
    private static let hiddenInPreviousVersionPrefix = "asset.presentation.hidden_in_previous_version"
    /// Assets hidden in the previous version that hold funds and that the user
    /// chose to keep hidden from the portfolio notice.
    private static let hiddenFundsReviewedPrefix = "asset.presentation.hidden_funds_reviewed"
    private static let migrationLock = NSLock()
    private static let legacyHintsLock = NSLock()

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
        writePreference(preference, walletId: walletId, assetKey: assetKey, userDefaults: userDefaults)

        // Any choice the user makes here, "Reset to automatic" included,
        // replaces what the previous version recorded for the asset.
        legacyHintsLock.lock()
        defer { legacyHintsLock.unlock() }
        for hintPrefix in [legacyZeroHiddenPrefix, hiddenInPreviousVersionPrefix] {
            remove([assetKey], from: hintPrefix, walletId: walletId, userDefaults: userDefaults)
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

    static func legacyZeroHidden(
        walletId: String,
        userDefaults: UserDefaults = .standard
    ) -> AssetKeySet {
        let identifiers = storedIdentifiers(legacyZeroHiddenPrefix, walletId: walletId, userDefaults: userDefaults)
        return AssetKeySet(identifiers: identifiers)
    }

    static func isLegacyZeroHidden(
        walletId: String,
        assetKey: AssetKey,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        legacyZeroHidden(walletId: walletId, userDefaults: userDefaults).contains(assetKey)
    }

    /// Explicit Hidden preferences the migration carried over from a 4.0.4 TON
    /// wallet and the user has not changed since.
    static func hiddenInPreviousVersion(
        walletId: String,
        userDefaults: UserDefaults = .standard
    ) -> AssetKeySet {
        let identifiers = storedIdentifiers(
            hiddenInPreviousVersionPrefix,
            walletId: walletId,
            userDefaults: userDefaults
        )
        return AssetKeySet(identifiers: identifiers)
    }

    /// Assets the "N hidden assets hold funds" notice no longer asks about.
    static func reviewedHiddenFunds(walletId: String, userDefaults: UserDefaults = .standard) -> AssetKeySet {
        let identifiers = storedIdentifiers(hiddenFundsReviewedPrefix, walletId: walletId, userDefaults: userDefaults)
        return AssetKeySet(identifiers: identifiers)
    }

    /// "Keep hidden" on the notice; writes no preference, the assets stay Hidden.
    static func markHiddenFundsReviewed(
        _ assetKeys: [AssetKey],
        walletId: String,
        userDefaults: UserDefaults = .standard
    ) {
        legacyHintsLock.lock()
        defer { legacyHintsLock.unlock() }
        insert(assetKeys, into: hiddenFundsReviewedPrefix, walletId: walletId, userDefaults: userDefaults)
    }

    /// Maps the App Store 4.0.4 rows (`wallet.assetsVisibility`, never modified)
    /// onto AssetKey preferences once per wallet after a complete catalog read,
    /// and returns the asset keys whose presentation changed. 4.0.4 rewrote
    /// `hidden = isZero` on every scan of a regular wallet, so a regular hide
    /// only means "held nothing then": Auto plus a hide-while-zero hint. TON
    /// wallets listed every row not hidden, so their hides stay explicit Hidden.
    /// Preferences the TestFlight 2026.9.x builds stored on their own go back
    /// to Auto first; only user actions write Shown or Hidden from here on.
    @discardableResult
    static func migrateLegacyHides(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        catalogIsComplete: Bool,
        userDefaults: UserDefaults = .standard
    ) -> [AssetKey] {
        guard catalogIsComplete else {
            return []
        }

        migrationLock.lock()
        defer { migrationLock.unlock() }

        let walletId = wallet.metaId
        let migrationKey = [migrationV2Prefix, walletId].joined(separator: ":")
        guard !userDefaults.bool(forKey: migrationKey) else {
            return []
        }

        let index = LegacyVisibilityIndex(chainAssets: chainAssets)
        var changed: [AssetKey] = []

        // The first migration turned every legacy row into an explicit choice,
        // so funded assets that 4.0.4 had hidden at zero stayed hidden. Undo
        // exactly what it wrote and nobody changed since; choices made later,
        // on these or any other assets, stay.
        if userDefaults.bool(forKey: [migrationPrefix, walletId].joined(separator: ":")) {
            let firstMigration = index.firstMigrationPreferences(for: wallet.assetsVisibility)
            for (assetKey, written) in firstMigration
                where preference(walletId: walletId, assetKey: assetKey, userDefaults: userDefaults) == written {
                writePreference(.auto, walletId: walletId, assetKey: assetKey, userDefaults: userDefaults)
                changed.append(assetKey)
            }

            // The same builds stored Shown on every scan for each ranked
            // network's utility asset (Taira Testnet included) that was still
            // Auto. An asset the first migration had given a preference was
            // never Auto, so a Shown there is the user's and stays; the rest
            // go back to Auto, where the zero rule shows them as before.
            let firstMigrationKeys = Set(firstMigration.map(\.0))
            for assetKey in index.scanShownAssetKeys() where !firstMigrationKeys.contains(assetKey) &&
                preference(walletId: walletId, assetKey: assetKey, userDefaults: userDefaults) == .shown {
                writePreference(.auto, walletId: walletId, assetKey: assetKey, userDefaults: userDefaults)
                changed.append(assetKey)
            }
        }

        let isLegacyTonWallet = wallet.legacyTonAccount != nil && wallet.substratePublicKey == nil
        // Only Auto assets take the legacy mapping: a choice made in this
        // version before the migration ran always wins.
        let legacyHidden = index.hiddenAssetKeys(
            for: wallet.assetsVisibility,
            allowsBroadMatches: !isLegacyTonWallet
        ).filter {
            preference(walletId: walletId, assetKey: $0, userDefaults: userDefaults) == .auto
        }

        if isLegacyTonWallet {
            for assetKey in legacyHidden {
                writePreference(.hidden, walletId: walletId, assetKey: assetKey, userDefaults: userDefaults)
            }
        }

        legacyHintsLock.lock()
        insert(
            legacyHidden,
            into: isLegacyTonWallet ? hiddenInPreviousVersionPrefix : legacyZeroHiddenPrefix,
            walletId: walletId,
            userDefaults: userDefaults
        )
        legacyHintsLock.unlock()

        userDefaults.set(true, forKey: migrationKey)

        var seen = Set<AssetKey>()
        return (changed + legacyHidden).filter { seen.insert($0).inserted }
    }

    static func storageIdentifier(for assetKey: AssetKey) -> String {
        [assetKey.ecosystem, assetKey.chainId, assetKey.assetId].joined(separator: ":")
    }

    private static func writePreference(
        _ preference: AssetPreference,
        walletId: String,
        assetKey: AssetKey,
        userDefaults: UserDefaults
    ) {
        let storageKey = key(walletId: walletId, assetKey: assetKey)
        if preference == .auto {
            userDefaults.removeObject(forKey: storageKey)
        } else {
            userDefaults.set(preference.rawValue, forKey: storageKey)
        }
    }

    private static func storedIdentifiers(
        _ hintPrefix: String,
        walletId: String,
        userDefaults: UserDefaults
    ) -> Set<String> {
        Set(userDefaults.stringArray(forKey: [hintPrefix, walletId].joined(separator: ":")) ?? [])
    }

    /// Caller holds `legacyHintsLock`.
    private static func insert(
        _ assetKeys: [AssetKey],
        into hintPrefix: String,
        walletId: String,
        userDefaults: UserDefaults
    ) {
        guard !assetKeys.isEmpty else {
            return
        }

        let identifiers = storedIdentifiers(hintPrefix, walletId: walletId, userDefaults: userDefaults)
            .union(assetKeys.map(storageIdentifier(for:)))
        userDefaults.set(identifiers.sorted(), forKey: [hintPrefix, walletId].joined(separator: ":"))
    }

    /// Caller holds `legacyHintsLock`.
    private static func remove(
        _ assetKeys: [AssetKey],
        from hintPrefix: String,
        walletId: String,
        userDefaults: UserDefaults
    ) {
        let stored = storedIdentifiers(hintPrefix, walletId: walletId, userDefaults: userDefaults)
        let identifiers = stored.subtracting(assetKeys.map(storageIdentifier(for:)))
        guard identifiers.count != stored.count else {
            return
        }

        let storageKey = [hintPrefix, walletId].joined(separator: ":")
        if identifiers.isEmpty {
            userDefaults.removeObject(forKey: storageKey)
        } else {
            userDefaults.set(identifiers.sorted(), forKey: storageKey)
        }
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
