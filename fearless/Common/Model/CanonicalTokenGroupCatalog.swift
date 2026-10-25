import Foundation
import SSFModels

/// A reviewed token group from the shared `canonical-asset-groups.v1.json`
/// (root repository `config/token-groups/`, docs/portfolio-contract.md). A
/// group never supplies a price: its fiat value is always the sum of each
/// member's own priced balance.
struct CanonicalTokenGroup: Equatable, Hashable {
    struct Member: Hashable {
        let chainId: ChainModel.Id
        let assetId: AssetModel.Id
        let symbol: String
        let precision: UInt16
    }

    let id: String
    let symbol: String
    let name: String
    /// Validation only: every member's registry `priceId` must equal it.
    let priceId: AssetModel.PriceId?
    let members: [Member]
}

/// Resolves registry assets to the curated groups bundled with the app. Groups
/// are never derived from symbols, `xc` prefixes or shared price ids: an asset
/// joins a group only when the reviewed file lists its exact
/// `(chainId, assetId)` and the live registry still describes it the way it was
/// reviewed. Any doubt leaves the asset as its own row, which can never merge
/// two holdings by mistake.
final class CanonicalTokenGroupCatalog {
    static let resourceName = "canonical-asset-groups.v1"
    static let bundled = CanonicalTokenGroupCatalog(bundle: .main)

    static let maxGroups = 200
    static let maxMembersPerGroup = 64

    /// Approved groups that survived validation, in file order.
    let groups: [CanonicalTokenGroup]
    let testnets: PortfolioTestnetChainList
    /// Assets listed in the same file as having no trusted price. They are
    /// never grouped, even if a group lists them.
    let untrustedPrices: PortfolioUntrustedPriceList

    private let entriesByChainId: [ChainModel.Id: [Entry]]
    private let userDefaults: UserDefaults

    private struct Entry {
        let group: CanonicalTokenGroup
        let member: CanonicalTokenGroup.Member
    }

    convenience init(bundle: Bundle, userDefaults: UserDefaults = .standard) {
        self.init(
            data: PortfolioSharedConfigResource.data(named: Self.resourceName, in: bundle),
            testnets: PortfolioTestnetChainList(bundle: bundle),
            userDefaults: userDefaults
        )
    }

    /// Any missing, unreadable or invalid file yields an empty catalog.
    init(
        data: Data?,
        testnets: PortfolioTestnetChainList,
        userDefaults: UserDefaults = .standard
    ) {
        let groups = data.flatMap { Self.approvedGroups(from: $0) } ?? []

        self.groups = groups
        self.testnets = testnets
        untrustedPrices = PortfolioUntrustedPriceList(data: data)
        self.userDefaults = userDefaults

        var entriesByChainId: [ChainModel.Id: [Entry]] = [:]
        for group in groups {
            for member in group.members {
                entriesByChainId[member.chainId.lowercased(), default: []].append(
                    Entry(group: group, member: member)
                )
            }
        }
        self.entriesByChainId = entriesByChainId
    }

    /// The group `chainAsset` belongs to, or nil. A listed member counts only
    /// while its chain is enabled and not a testnet, the registry still
    /// reports the reviewed symbol, precision and price id, the asset's
    /// metadata comes from the registry rather than an indexer, and its
    /// registry price is trusted.
    func group(for chainAsset: ChainAsset) -> CanonicalTokenGroup? {
        let chain = chainAsset.chain
        let asset = chainAsset.asset

        guard
            !chain.disabled,
            !testnets.isTestnet(chain),
            !untrustedPrices.contains(chainAsset),
            let entries = entriesByChainId[chain.chainId.lowercased()],
            let entry = entries.first(where: {
                PortfolioSharedConfigResource.assetIdsMatch($0.member.assetId, asset.id, on: chain)
            }),
            asset.symbol.lowercased() == entry.member.symbol.lowercased(),
            asset.precision == entry.member.precision,
            entry.group.priceId == nil || asset.coingeckoPriceId == entry.group.priceId
        else {
            return nil
        }

        let trust = AssetTrustResolver.metadataTrust(for: chainAsset, userDefaults: userDefaults)
        guard trust.trust == .verified, trust.provenance == .registry else {
            return nil
        }

        return entry.group
    }

    /// The candidates that resolve to `group`, one per asset key, in the
    /// group file's member order.
    func members(of group: CanonicalTokenGroup, among chainAssets: [ChainAsset]) -> [ChainAsset] {
        var seenKeys = Set<AssetKey>()
        let resolved = chainAssets.filter { chainAsset in
            guard self.group(for: chainAsset)?.id == group.id else {
                return false
            }
            return seenKeys.insert(chainAsset.assetKey).inserted
        }

        func position(of chainAsset: ChainAsset) -> Int {
            group.members.firstIndex {
                $0.chainId.lowercased() == chainAsset.chain.chainId.lowercased() &&
                    PortfolioSharedConfigResource.assetIdsMatch($0.assetId, chainAsset.asset.id, on: chainAsset.chain)
            } ?? group.members.count
        }

        return resolved.sorted { position(of: $0) < position(of: $1) }
    }

    /// True only when both assets resolve to the same group. Ungrouped assets
    /// are never the "same token" as anything else.
    func isSameGroup(_ lhs: ChainAsset, _ rhs: ChainAsset) -> Bool {
        guard let lhsGroup = group(for: lhs), let rhsGroup = group(for: rhs) else {
            return false
        }
        return lhsGroup.id == rhsGroup.id
    }
}

private extension CanonicalTokenGroupCatalog {
    static let format = "fearless.canonical-asset-groups"
    static let approvedStatus = "approved"
    static let registryKind = "registry"

    struct File: Decodable {
        let format: String
        let version: Int
        let groups: [Group]
    }

    struct Group: Decodable {
        let id: String
        let symbol: String
        let name: String
        let status: String
        let priceId: String?
        let symbolAliases: [String]?
        let members: [Member]
    }

    struct Member: Decodable {
        let chainId: String
        let assetId: String
        let symbol: String
        let precision: UInt16
        let kind: String?
    }

    static func approvedGroups(from data: Data) -> [CanonicalTokenGroup]? {
        guard
            let file = try? JSONDecoder().decode(File.self, from: data),
            file.format == format,
            file.version == 1,
            file.groups.count <= maxGroups,
            file.groups.allSatisfy({ isValidGroupId($0.id) && $0.members.count <= maxMembersPerGroup }),
            Set(file.groups.map(\.id)).count == file.groups.count
        else {
            return nil
        }

        // A (chainId, assetId) listed twice, in any group and whatever its
        // status, makes every group that lists it unusable. Asset ids compare
        // case-insensitively here so a casing variant can never slip through.
        var owners: [String: [String]] = [:]
        for group in file.groups {
            for member in group.members {
                owners[identity(of: member), default: []].append(group.id)
            }
        }
        let invalidGroupIds = Set(owners.values.filter { $0.count > 1 }.joined())

        return file.groups.compactMap { group in
            guard group.status == approvedStatus, !invalidGroupIds.contains(group.id) else {
                return nil
            }

            let symbols = Set(([group.symbol] + (group.symbolAliases ?? [])).map { $0.lowercased() })
            let members = group.members
                .filter { ($0.kind ?? registryKind) == registryKind && symbols.contains($0.symbol.lowercased()) }
                .map {
                    CanonicalTokenGroup.Member(
                        chainId: $0.chainId,
                        assetId: $0.assetId,
                        symbol: $0.symbol,
                        precision: $0.precision
                    )
                }

            guard !members.isEmpty else {
                return nil
            }

            return CanonicalTokenGroup(
                id: group.id,
                symbol: group.symbol,
                name: group.name,
                priceId: group.priceId,
                members: members
            )
        }
    }

    static func identity(of member: Member) -> String {
        [member.chainId.lowercased(), member.assetId.lowercased()].joined(separator: "\u{0}")
    }

    static func isValidGroupId(_ identifier: String) -> Bool {
        identifier.range(of: "^[a-z0-9][a-z0-9-]{0,31}$", options: .regularExpression) != nil
    }
}

/// The shared testnet list (`testnet-chain-ids.v1.json`): networks treated as
/// testnets in addition to the registry `testnet` option. Testnets are never
/// grouped, never zero defaults and never counted in totals.
struct PortfolioTestnetChainList {
    static let resourceName = "testnet-chain-ids.v1"
    static let format = "fearless.testnet-chain-ids"
    static let bundled = PortfolioTestnetChainList(bundle: .main)

    /// Lowercased chain ids. Empty when the file could not be read; the
    /// registry option still applies then.
    let chainIds: Set<ChainModel.Id>

    init(chainIds: Set<ChainModel.Id>) {
        self.chainIds = Set(chainIds.map { $0.lowercased() })
    }

    init(data: Data?) {
        let file = data.flatMap { try? JSONDecoder().decode(TestnetChainIdsFile.self, from: $0) }
        guard let file, file.format == Self.format, file.version == 1 else {
            self.init(chainIds: [])
            return
        }

        self.init(chainIds: Set(file.chainIds.map(\.chainId)))
    }

    init(bundle: Bundle) {
        self.init(data: PortfolioSharedConfigResource.data(named: Self.resourceName, in: bundle))
    }

    var isLoaded: Bool {
        !chainIds.isEmpty
    }

    func isTestnet(_ chain: ChainModel) -> Bool {
        chain.isTestnet || chainIds.contains(chain.chainId.lowercased())
    }
}

/// The account a wallet needs before a network's zero default applies.
/// Mirrors `ACCOUNT_FOR_ECOSYSTEM` in the root `scripts/portfolio-config.mjs`:
/// Moonbeam-style `ethereumBased` networks use the wallet's EVM account.
enum PortfolioAccountFamily: String, CaseIterable {
    case substrate
    case evm
    case ton
    case bitcoin
    case solana
    case iroha

    init?(ecosystem: String) {
        switch ecosystem {
        case "ethereum", "ethereumBased":
            self = .evm
        case Self.evm.rawValue:
            // An account family, not a registry ecosystem.
            return nil
        default:
            self.init(rawValue: ecosystem)
        }
    }
}

/// The listed part of the one zero rule (`default-visible-at-zero.v1.json`):
/// the only Auto assets shown at zero balance, besides the primary utility
/// asset of a favourite or only-selected network. Explicit Shown and Hidden
/// choices always win over this list.
struct PortfolioZeroDefaultList {
    static let resourceName = "default-visible-at-zero.v1"
    static let format = "fearless.default-visible-at-zero"
    static let bundled = PortfolioZeroDefaultList(bundle: .main)

    struct Entry: Equatable, Decodable {
        let chainId: ChainModel.Id
        let assetId: AssetModel.Id
        let symbol: String
        let network: String
        let ecosystem: String

        var accountFamily: PortfolioAccountFamily? {
            PortfolioAccountFamily(ecosystem: ecosystem)
        }
    }

    /// Entries in file order. Empty when the file could not be read; callers
    /// then use the computed fallback (primary utility asset of a ranked,
    /// non-testnet network).
    let entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries
    }

    init(data: Data?) {
        let file = data.flatMap { try? JSONDecoder().decode(ZeroDefaultsFile.self, from: $0) }
        guard let file, file.format == Self.format, file.version == 1 else {
            self.init(entries: [])
            return
        }

        self.init(entries: file.entries)
    }

    init(bundle: Bundle) {
        self.init(data: PortfolioSharedConfigResource.data(named: Self.resourceName, in: bundle))
    }

    var isLoaded: Bool {
        !entries.isEmpty
    }

    /// Entries for a wallet holding `accountFamilies`, minus networks whose
    /// send is currently vetoed (a vetoed network never invites deposits).
    func entries(
        for accountFamilies: Set<PortfolioAccountFamily>,
        sendVetoedChainIds: Set<ChainModel.Id> = []
    ) -> [Entry] {
        let vetoed = Set(sendVetoedChainIds.map { $0.lowercased() })

        return entries.filter { entry in
            guard let family = entry.accountFamily else {
                return false
            }
            return accountFamilies.contains(family) && !vetoed.contains(entry.chainId.lowercased())
        }
    }

    func contains(_ chainAsset: ChainAsset) -> Bool {
        let chainId = chainAsset.chain.chainId.lowercased()

        return entries.contains {
            $0.chainId.lowercased() == chainId &&
                PortfolioSharedConfigResource.assetIdsMatch($0.assetId, chainAsset.asset.id, on: chainAsset.chain)
        }
    }
}

/// Registry assets whose registry price must not be trusted (`untrustedAssets`
/// in `canonical-asset-groups.v1.json`, portfolio contract §3): for example a
/// third-party token the registry prices as Tether. A listed asset keeps its
/// row and its balance, but adds no fiat anywhere and is never grouped.
struct PortfolioUntrustedPriceList {
    static let bundled = PortfolioUntrustedPriceList(bundle: .main)

    struct Entry: Equatable, Decodable {
        let chainId: ChainModel.Id
        let assetId: AssetModel.Id
    }

    /// Entries in file order. Empty when the file could not be read or lists
    /// none.
    let entries: [Entry]

    private let assetIdsByChainId: [ChainModel.Id: [AssetModel.Id]]

    init(entries: [Entry]) {
        self.entries = entries
        assetIdsByChainId = Dictionary(grouping: entries) { $0.chainId.lowercased() }
            .mapValues { $0.map(\.assetId) }
    }

    /// Reads the list on its own, so a groups file that is unusable for
    /// grouping still withholds these prices.
    init(data: Data?) {
        let file = data.flatMap { try? JSONDecoder().decode(UntrustedAssetsFile.self, from: $0) }
        guard let file, file.format == CanonicalTokenGroupCatalog.format, file.version == 1 else {
            self.init(entries: [])
            return
        }

        self.init(entries: file.untrustedAssets ?? [])
    }

    init(bundle: Bundle) {
        self.init(data: PortfolioSharedConfigResource.data(named: CanonicalTokenGroupCatalog.resourceName, in: bundle))
    }

    func contains(_ chainAsset: ChainAsset) -> Bool {
        guard let assetIds = assetIdsByChainId[chainAsset.chain.chainId.lowercased()] else {
            return false
        }

        return assetIds.contains {
            PortfolioSharedConfigResource.assetIdsMatch($0, chainAsset.asset.id, on: chainAsset.chain)
        }
    }
}

/// Reading and matching rules shared by the three bundled portfolio files.
enum PortfolioSharedConfigResource {
    static func data(named name: String, in bundle: Bundle) -> Data? {
        bundle.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }

    /// Registry asset ids compare exactly, except on EVM networks, where they
    /// are contract addresses and compare case-insensitively (as `AssetKey`).
    static func assetIdsMatch(_ listed: AssetModel.Id, _ registry: AssetModel.Id, on chain: ChainModel) -> Bool {
        if AssetKey.ecosystem(for: chain) == "evm" {
            return listed.lowercased() == registry.lowercased()
        }
        return listed == registry
    }
}

private struct UntrustedAssetsFile: Decodable {
    let format: String
    let version: Int
    let untrustedAssets: [PortfolioUntrustedPriceList.Entry]?
}

private struct TestnetChainIdsFile: Decodable {
    struct Entry: Decodable {
        let chainId: String
    }

    let format: String
    let version: Int
    let chainIds: [Entry]
}

private struct ZeroDefaultsFile: Decodable {
    let format: String
    let version: Int
    let entries: [PortfolioZeroDefaultList.Entry]
}
