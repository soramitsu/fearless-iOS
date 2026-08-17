import Foundation
import RobinHood
import SSFModels

extension ChainAsset {
    var assetDisplayInfo: AssetBalanceDisplayInfo { asset.displayInfo(with: chain.icon) }

    var identifier: String {
        [chain.identifier, asset.id].joined(separator: " : ")
    }

    var assetKey: AssetKey {
        AssetKey(
            ecosystem: AssetKey.ecosystem(for: chain),
            chainId: chain.chainId,
            assetId: asset.canonicalAssetId
        )
    }

    var storagePath: StorageCodingPath {
        guard let substrateType = chainAssetType else {
            return .account
        }

        switch substrateType {
        case .normal, .equilibrium:
            return .account
        case
            .ormlChain,
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCrowdloan,
            .vToken,
            .vsToken,
            .stable,
            .assetId,
            .token2,
            .xcm:
            return .tokens
        case .assets:
            return .assetsAccount
        case .soraAsset:
            return isUtility ? .account : .tokens
        }
    }

    var isBokolo: Bool {
        asset.currencyId == BokoloConstants.bokoloCashAssetCurrencyId
    }
}

extension AssetModel {
    /// Registry `id` identifies a row inside the client catalog, while
    /// `currencyId` is the runtime identity used by SORA, assets-pallet, ORML
    /// and other typed assets. Dynamic TON, Solana, Iroha and EVM assets already
    /// store their master/mint/definition/contract in `currencyId` (and usually
    /// in `id` too), so this precedence is stable across every client.
    var canonicalAssetId: AssetModel.Id {
        guard let currencyId, !currencyId.isEmpty else {
            return id
        }
        return currencyId
    }
}

/// Stable identity used by portfolio, discovery and price accounting. Display
/// symbols and names deliberately do not participate in equality.
struct AssetKey: Hashable, Codable {
    let ecosystem: String
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id

    init(ecosystem: String, chainId: ChainModel.Id, assetId: AssetModel.Id) {
        let normalizedEcosystem = ecosystem.lowercased()
        self.ecosystem = normalizedEcosystem
        self.chainId = chainId.lowercased()
        self.assetId = normalizedEcosystem == "evm" ? assetId.lowercased() : assetId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            ecosystem: try container.decode(String.self, forKey: .ecosystem),
            chainId: try container.decode(ChainModel.Id.self, forKey: .chainId),
            assetId: try container.decode(AssetModel.Id.self, forKey: .assetId)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ecosystem, forKey: .ecosystem)
        try container.encode(chainId, forKey: .chainId)
        try container.encode(assetId, forKey: .assetId)
    }

    private enum CodingKeys: String, CodingKey {
        case ecosystem
        case chainId
        case assetId
    }

    static func ecosystem(for chain: ChainModel) -> String {
        let identifier = chain.chainId.lowercased()

        if chain.isTonCompatibilityChain || identifier.hasPrefix("ton:") {
            return "ton"
        } else if identifier.hasPrefix("bitcoin:") {
            return "bitcoin"
        } else if identifier.hasPrefix("solana:") {
            return "solana"
        } else if identifier.hasPrefix("iroha") || identifier.hasPrefix("sora:nexus") {
            return "iroha"
        } else if chain.isEthereumBased {
            return "evm"
        } else {
            return "substrate"
        }
    }
}

/// Resolves only relationships explicitly curated by the registry XCM
/// configuration. A display symbol (including an `xc` prefix) is never proof
/// that two contracts or runtime assets represent the same holding.
enum CuratedAssetRelationshipResolver {
    static func relatedChainAssets(
        to origin: ChainAsset,
        among candidates: [ChainAsset]
    ) -> [ChainAsset] {
        var allowedKeys = Set([origin.assetKey])

        if let xcm = origin.chain.xcm,
           xcm.availableAssets.filter({ $0.id == origin.asset.id }).count == 1 {
            let destinations = xcm.availableDestinations.filter { destination in
                destination.assets.filter { $0.id == origin.asset.id }.count == 1
            }
            for destination in destinations {
                candidates.filter {
                    $0.chain.chainId == destination.chainId &&
                        $0.asset.id == origin.asset.id
                }.forEach { allowedKeys.insert($0.assetKey) }
            }
        }

        let unique = Dictionary(
            grouping: candidates.filter { allowedKeys.contains($0.assetKey) },
            by: \.assetKey
        ).compactMap { _, matches in
            matches.sorted { $0.identifier < $1.identifier }.first
        }

        return unique.sorted {
            ($0.chain.name, $0.assetKey.chainId, $0.assetKey.assetId) <
                ($1.chain.name, $1.assetKey.chainId, $1.assetKey.assetId)
        }
    }

    static func hasCuratedXcmDestination(for origin: ChainAsset) -> Bool {
        guard let xcm = origin.chain.xcm,
              xcm.availableAssets.filter({ $0.id == origin.asset.id }).count == 1 else {
            return false
        }

        return xcm.availableDestinations.contains { destination in
            destination.assets.filter { $0.id == origin.asset.id }.count == 1
        }
    }
}

enum AssetMetadataTrust: String, Codable {
    case verified
    case unverified
    case missing
}

enum AssetMetadataProvenance: String, Codable {
    case registry
    case chain
    case indexer
}

enum PriceTrust: String, Codable {
    case canonicalAsset
    case curatedGroup
    case unavailable

    var contributesToPortfolioTotal: Bool {
        self != .unavailable
    }
}

struct AssetMetadataTrustInfo: Equatable {
    let trust: AssetMetadataTrust
    let provenance: AssetMetadataProvenance
}

/// Dynamically discovered assets are recorded separately from the signed chain
/// registry. This prevents an indexer-supplied symbol or price from being
/// mistaken for a curated asset after the chain model is refreshed.
enum AssetTrustResolver {
    private static let discoveredKey = "portfolio.asset.metadata.unverified"
    private static let missingKey = "portfolio.asset.metadata.missing"
    private static let verifiedIndexerKey = "portfolio.asset.metadata.verified.indexer"
    private static let lock = NSLock()

    static func markUnverified(_ chainAsset: ChainAsset, userDefaults: UserDefaults = .standard) {
        lock.lock()
        defer { lock.unlock() }

        let identifier = storageIdentifier(for: chainAsset)
        var identifiers = Set(userDefaults.stringArray(forKey: discoveredKey) ?? [])
        identifiers.insert(identifier)
        userDefaults.set(Array(identifiers), forKey: discoveredKey)
        remove(identifier, from: missingKey, userDefaults: userDefaults)
        remove(chainAsset.identifier, from: missingKey, userDefaults: userDefaults)
        remove(identifier, from: verifiedIndexerKey, userDefaults: userDefaults)
        remove(chainAsset.identifier, from: verifiedIndexerKey, userDefaults: userDefaults)
    }

    static func markMissing(_ chainAsset: ChainAsset, userDefaults: UserDefaults = .standard) {
        lock.lock()
        defer { lock.unlock() }

        let identifier = storageIdentifier(for: chainAsset)
        var identifiers = Set(userDefaults.stringArray(forKey: missingKey) ?? [])
        identifiers.insert(identifier)
        userDefaults.set(Array(identifiers), forKey: missingKey)
        remove(identifier, from: discoveredKey, userDefaults: userDefaults)
        remove(chainAsset.identifier, from: discoveredKey, userDefaults: userDefaults)
        remove(identifier, from: verifiedIndexerKey, userDefaults: userDefaults)
        remove(chainAsset.identifier, from: verifiedIndexerKey, userDefaults: userDefaults)
    }

    static func markVerifiedFromIndexer(
        _ chainAsset: ChainAsset,
        userDefaults: UserDefaults = .standard
    ) {
        lock.lock()
        defer { lock.unlock() }

        let identifier = storageIdentifier(for: chainAsset)
        var identifiers = Set(userDefaults.stringArray(forKey: verifiedIndexerKey) ?? [])
        identifiers.insert(identifier)
        userDefaults.set(Array(identifiers), forKey: verifiedIndexerKey)
        remove(identifier, from: discoveredKey, userDefaults: userDefaults)
        remove(chainAsset.identifier, from: discoveredKey, userDefaults: userDefaults)
        remove(identifier, from: missingKey, userDefaults: userDefaults)
        remove(chainAsset.identifier, from: missingKey, userDefaults: userDefaults)
    }

    static func metadataTrust(
        for chainAsset: ChainAsset,
        userDefaults: UserDefaults = .standard
    ) -> AssetMetadataTrustInfo {
        lock.lock()
        let identifier = storageIdentifier(for: chainAsset)
        let legacyIdentifier = chainAsset.identifier
        let isMissing = contains(
            identifier,
            legacyIdentifier: legacyIdentifier,
            in: missingKey,
            userDefaults: userDefaults
        )
        let isDiscovered = contains(
            identifier,
            legacyIdentifier: legacyIdentifier,
            in: discoveredKey,
            userDefaults: userDefaults
        )
        let isVerifiedIndexer = contains(
            identifier,
            legacyIdentifier: legacyIdentifier,
            in: verifiedIndexerKey,
            userDefaults: userDefaults
        )
        lock.unlock()

        if isMissing {
            return AssetMetadataTrustInfo(trust: .missing, provenance: .chain)
        }
        if isDiscovered {
            return AssetMetadataTrustInfo(trust: .unverified, provenance: .indexer)
        }
        if isVerifiedIndexer {
            return AssetMetadataTrustInfo(trust: .verified, provenance: .indexer)
        }

        return AssetMetadataTrustInfo(trust: .verified, provenance: .registry)
    }

    static func priceTrust(for chainAsset: ChainAsset, currency: Currency) -> PriceTrust {
        guard metadataTrust(for: chainAsset).trust == .verified,
              chainAsset.asset.getPrice(for: currency) != nil else {
            return .unavailable
        }

        return .canonicalAsset
    }

    private static func storageIdentifier(for chainAsset: ChainAsset) -> String {
        let key = chainAsset.assetKey
        return [key.ecosystem, key.chainId, key.assetId].joined(separator: ":")
    }

    private static func contains(
        _ identifier: String,
        legacyIdentifier: String,
        in key: String,
        userDefaults: UserDefaults
    ) -> Bool {
        let identifiers = Set(userDefaults.stringArray(forKey: key) ?? [])
        return identifiers.contains(identifier) || identifiers.contains(legacyIdentifier)
    }

    /// Caller holds `lock`.
    private static func remove(_ identifier: String, from key: String, userDefaults: UserDefaults) {
        var identifiers = Set(userDefaults.stringArray(forKey: key) ?? [])
        identifiers.remove(identifier)
        userDefaults.set(Array(identifiers), forKey: key)
    }
}

enum TonJettonMetadataTrust {
    static func isVerified(_ verification: String?) -> Bool {
        guard let verification = verification?.lowercased() else {
            return false
        }

        return verification == "whitelist" || verification == "verified"
    }

    static func apply(to chainAsset: ChainAsset, verification: String?) {
        if isVerified(verification) {
            AssetTrustResolver.markVerifiedFromIndexer(chainAsset)
        } else {
            AssetTrustResolver.markUnverified(chainAsset)
        }
    }
}

enum DynamicAssetPrecisionStore {
    private static let prefix = "portfolio.asset.dynamic.precision"

    static func precision(for key: AssetKey, userDefaults: UserDefaults = .standard) -> UInt16? {
        let key = storageKey(key)
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }
        return UInt16(exactly: userDefaults.integer(forKey: key))
    }

    static func remember(
        _ precision: UInt16,
        for key: AssetKey,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(Int(precision), forKey: storageKey(key))
    }

    private static func storageKey(_ key: AssetKey) -> String {
        [prefix, key.ecosystem, key.chainId, key.assetId].joined(separator: ":")
    }
}

enum AssetDiscoveryCoverage: String, Codable {
    case complete
    case catalogOnly
    case limited

    var title: String {
        switch self {
        case .complete:
            return NSLocalizedString("portfolio.discovery.complete", value: "Full discovery", comment: "")
        case .catalogOnly:
            return NSLocalizedString("portfolio.discovery.catalog_only", value: "Catalog only", comment: "")
        case .limited:
            return NSLocalizedString("portfolio.discovery.limited", value: "Limited discovery", comment: "")
        }
    }

    static func forChain(_ chain: ChainModel) -> AssetDiscoveryCoverage {
        let identifier = chain.chainId.lowercased()

        if chain.isTonCompatibilityChain || identifier.hasPrefix("ton:") {
            return .complete
        } else if identifier.hasPrefix("solana:") ||
            identifier.hasPrefix("iroha") ||
            identifier.hasPrefix("sora:nexus") {
            return .complete
        } else if identifier.hasPrefix("bitcoin:") {
            return .limited
        } else {
            return .catalogOnly
        }
    }
}

struct NetworkScanState: Codable, Equatable {
    let lastAttempt: Date?
    let lastSuccess: Date?
    let hasError: Bool
    let coverage: AssetDiscoveryCoverage

    var isStale: Bool {
        isStale(at: Date())
    }

    func isStale(at now: Date) -> Bool {
        guard let lastSuccess else {
            return true
        }
        return now.timeIntervalSince(lastSuccess) > 36 * 60 * 60
    }

    var displayText: String {
        displayText(now: Date())
    }

    func displayText(now: Date) -> String {
        let freshness = freshnessText(now: now)
        if hasError {
            return [
                NSLocalizedString("portfolio.discovery.error", value: "Sync error", comment: ""),
                coverage.title,
                freshness
            ].joined(separator: " · ")
        } else if isStale(at: now) {
            return [
                NSLocalizedString("portfolio.discovery.stale", value: "Stale", comment: ""),
                coverage.title,
                freshness
            ].joined(separator: " · ")
        } else {
            return [coverage.title, freshness].joined(separator: " · ")
        }
    }

    private func freshnessText(now: Date) -> String {
        guard let lastSuccess else {
            return NSLocalizedString("portfolio.discovery.never_synced", value: "Never synced", comment: "")
        }
        let seconds = max(0, now.timeIntervalSince(lastSuccess))
        if seconds < 60 {
            return NSLocalizedString("portfolio.discovery.synced_now", value: "Synced just now", comment: "")
        } else if seconds < 60 * 60 {
            return "Synced \(max(1, Int(seconds / 60)))m ago"
        } else if seconds < 24 * 60 * 60 {
            return "Synced \(max(1, Int(seconds / (60 * 60))))h ago"
        } else {
            return "Synced \(max(1, Int(seconds / (24 * 60 * 60))))d ago"
        }
    }
}

enum NetworkScanStateStore {
    private static let prefix = "portfolio.network.scan"
    private static let lock = NSLock()

    static func markAttempt(
        for chain: ChainModel,
        walletId: MetaAccountId? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        let previous = state(for: chain, walletId: walletId, userDefaults: userDefaults)
        save(
            NetworkScanState(
                lastAttempt: Date(),
                lastSuccess: previous.lastSuccess,
                hasError: false,
                coverage: previous.coverage
            ),
            for: chain,
            walletId: walletId,
            userDefaults: userDefaults
        )
    }

    static func markSuccess(
        for chain: ChainModel,
        coverage: AssetDiscoveryCoverage? = nil,
        walletId: MetaAccountId? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        let now = Date()
        let resolvedCoverage = coverage ?? state(
            for: chain,
            walletId: walletId,
            userDefaults: userDefaults
        ).coverage
        save(
            NetworkScanState(
                lastAttempt: now,
                lastSuccess: now,
                hasError: false,
                coverage: resolvedCoverage
            ),
            for: chain,
            walletId: walletId,
            userDefaults: userDefaults
        )
    }

    static func markFailure(
        for chain: ChainModel,
        walletId: MetaAccountId? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        let previous = state(for: chain, walletId: walletId, userDefaults: userDefaults)
        save(
            NetworkScanState(
                lastAttempt: Date(),
                lastSuccess: previous.lastSuccess,
                hasError: true,
                coverage: previous.coverage
            ),
            for: chain,
            walletId: walletId,
            userDefaults: userDefaults
        )
    }

    static func state(
        for chain: ChainModel,
        walletId: MetaAccountId? = nil,
        userDefaults: UserDefaults = .standard
    ) -> NetworkScanState {
        lock.lock()
        let data = userDefaults.data(forKey: key(chain.chainId, walletId: walletId)) ??
            userDefaults.data(forKey: legacyKey(chain.chainId))
        lock.unlock()

        return data.flatMap { try? JSONDecoder().decode(NetworkScanState.self, from: $0) } ??
            NetworkScanState(
                lastAttempt: nil,
                lastSuccess: nil,
                hasError: false,
                coverage: AssetDiscoveryCoverage.forChain(chain)
            )
    }

    private static func save(
        _ state: NetworkScanState,
        for chain: ChainModel,
        walletId: MetaAccountId?,
        userDefaults: UserDefaults
    ) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        lock.lock()
        userDefaults.set(data, forKey: key(chain.chainId, walletId: walletId))
        lock.unlock()
    }

    private static func key(_ chainId: ChainModel.Id, walletId: MetaAccountId?) -> String {
        [prefix, walletId ?? "global", chainId].joined(separator: ":")
    }

    private static func legacyKey(_ chainId: ChainModel.Id) -> String {
        [prefix, chainId].joined(separator: ":")
    }
}
