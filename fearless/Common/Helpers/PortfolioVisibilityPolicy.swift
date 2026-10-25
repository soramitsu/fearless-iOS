import Foundation
import SSFModels

/// Where an asset goes in the portfolio list.
enum PortfolioPlacement: Equatable {
    /// A row in the main list.
    case visible
    /// Not listed: an explicit Hide, or an Auto testnet asset. Testnets stay out
    /// of the portfolio until the user shows them (Manage › Testnets) or picks
    /// the testnet as the only network.
    case hidden
    /// An unverified Auto holding: Detected only, never in totals.
    case detected
    /// An Auto asset without a balance that the zero rule leaves out of the
    /// main list. Manage still lists it, and a deposit makes it visible.
    case zeroCollapsed
}

/// Everything the visibility decision depends on, for one asset of one wallet.
struct PortfolioVisibilityInput: Equatable {
    var preference: AssetPreference = .auto
    /// Total balance (free + reserved), so staked or reserved funds count.
    var balanceIsPositive = false
    var isVerified = true
    var isTestnet = false
    /// The user filtered the portfolio to this network alone.
    var isOnlySelectedNetwork = false
    /// The wallet holds an account on this network. Zero rows need one.
    var hasAccount = true
    /// Listed in `default-visible-at-zero.v1.json` (or the computed fallback
    /// when that list is unavailable).
    var isListedZeroDefault = false
    /// The network's primary utility asset.
    var isPrimaryUtility = false
    var isFavouriteNetwork = false
    /// Sending is paused here: a remote kill switch vetoed it, or this build
    /// cannot send from this wallet on the network yet. Such a network never
    /// invites deposits with a zero row (critique G10).
    var isSendVetoed = false
    /// App Store 4.0.4 hid this asset automatically while it held nothing.
    var isLegacyZeroHidden = false
    /// An app-owned mainnet (Bitcoin, Solana) whose account the wallet can add in
    /// place: tapping the row sets the account up. Like any network without an
    /// account it stays out of the zero rows unless the user shows it.
    var offersAccountSetup = false
}

/// The one zero rule of the shared portfolio contract (root
/// `docs/portfolio-contract.md` §4) plus the iOS hide-while-zero hint for
/// App Store 4.0.4 data (§5). Only user actions write Shown or Hidden; every
/// other outcome is derived here from the balance and the network, so a later
/// deposit always appears.
enum PortfolioVisibilityPolicy {
    static func placement(_ input: PortfolioVisibilityInput) -> PortfolioPlacement {
        switch input.preference {
        case .hidden:
            return .hidden
        case .shown:
            // Shown is honoured at zero, but a network the wallet has no
            // account on has no row to show.
            return input.hasAccount || input.offersAccountSetup ? .visible : .zeroCollapsed
        case .auto:
            break
        }

        // Testnets come before the balance: test tokens have no value and a
        // funded testnet must not appear in the portfolio by default.
        if input.isTestnet, !input.isOnlySelectedNetwork {
            return .hidden
        }

        guard input.isVerified else {
            return input.balanceIsPositive ? .detected : .zeroCollapsed
        }

        // Balance wins over every hint: legacy data never hides funds.
        if input.balanceIsPositive {
            return .visible
        }

        if input.isLegacyZeroHidden || input.isTestnet || input.isSendVetoed {
            return .zeroCollapsed
        }

        // A network the wallet has no account on gets no zero row, Bitcoin and Solana
        // included (contract §4 `walletHoldsAccountFor`, critique C2). Their setup stays one
        // tap away in the collapsed networks and on an explicit Show.
        guard input.hasAccount else {
            return .zeroCollapsed
        }

        let isZeroDefault = input.isListedZeroDefault ||
            (input.isPrimaryUtility && (input.isFavouriteNetwork || input.isOnlySelectedNetwork))

        return isZeroDefault ? .visible : .zeroCollapsed
    }

    /// The network's primary utility asset: its utility asset, else its native
    /// one. `ChainModel.assets` is a set, so the registry order the shared
    /// definition uses is gone; ties prefer the listed zero default, then an
    /// asset that is also native, then the lowest id, which keeps the choice
    /// stable across launches.
    static func primaryUtilityAssetId(
        of chain: ChainModel,
        zeroDefaults: PortfolioZeroDefaultList
    ) -> AssetModel.Id? {
        let utilityAssets = chain.assets.filter(\.isUtility)
        let candidates = utilityAssets.isEmpty ? chain.assets.filter(\.isNative) : utilityAssets

        return candidates.min { lhs, rhs in
            let lhsListed = zeroDefaults.contains(ChainAsset(chain: chain, asset: lhs))
            let rhsListed = zeroDefaults.contains(ChainAsset(chain: chain, asset: rhs))
            if lhsListed != rhsListed {
                return lhsListed
            }
            if lhs.isNative != rhs.isNative {
                return lhs.isNative
            }
            return lhs.id < rhs.id
        }?.id
    }
}

/// Builds `PortfolioVisibilityInput` for one wallet from the preference store,
/// the legacy hints, the trust store and the bundled portfolio lists.
final class PortfolioVisibilityContext {
    let wallet: MetaAccountModel
    private let accountInfos: [ChainAssetKey: AccountInfo?]
    private let networkFilter: NetworkManagmentFilter?
    private let zeroDefaults: PortfolioZeroDefaultList
    private let testnets: PortfolioTestnetChainList
    private let sendVetoedChainIds: Set<ChainModel.Id>
    private let tonSendReleasePolicy: TonProductionSendReleasePolicy
    private let userDefaults: UserDefaults
    private let legacyZeroHidden: AssetKeySet
    private var primaryUtilityAssetIds: [ChainModel.Id: AssetModel.Id?] = [:]

    init(
        wallet: MetaAccountModel,
        accountInfos: [ChainAssetKey: AccountInfo?],
        networkFilter: NetworkManagmentFilter?,
        zeroDefaults: PortfolioZeroDefaultList = .bundled,
        testnets: PortfolioTestnetChainList = .bundled,
        sendVetoedChainIds: Set<ChainModel.Id> = [],
        tonSendReleasePolicy: TonProductionSendReleasePolicy = .production,
        userDefaults: UserDefaults = .standard
    ) {
        self.wallet = wallet
        self.accountInfos = accountInfos
        self.networkFilter = networkFilter
        self.zeroDefaults = zeroDefaults
        self.testnets = testnets
        self.sendVetoedChainIds = Set(sendVetoedChainIds.map { $0.lowercased() })
        self.tonSendReleasePolicy = tonSendReleasePolicy
        self.userDefaults = userDefaults
        legacyZeroHidden = AssetVisibilityPreferenceStore.legacyZeroHidden(
            walletId: wallet.metaId,
            userDefaults: userDefaults
        )
    }

    func placement(for chainAsset: ChainAsset) -> PortfolioPlacement {
        PortfolioVisibilityPolicy.placement(input(for: chainAsset))
    }

    func input(for chainAsset: ChainAsset) -> PortfolioVisibilityInput {
        let chain = chainAsset.chain
        let account = wallet.fetch(for: chain.accountRequest())
        let offersAccountSetup = Self.offersAccountSetup(chainAsset, wallet: wallet)
        let accountInfo = account.flatMap { accountInfos[chainAsset.uniqueKey(accountId: $0.accountId)] ?? nil }
        let isListedZeroDefault = zeroDefaults.isLoaded
            ? zeroDefaults.contains(chainAsset)
            : chain.rank != nil && isPrimaryUtility(chainAsset)

        return PortfolioVisibilityInput(
            preference: AssetVisibilityPreferenceStore.preference(
                walletId: wallet.metaId,
                assetKey: chainAsset.assetKey,
                userDefaults: userDefaults
            ),
            balanceIsPositive: accountInfo?.nonZero() == true,
            isVerified: AssetTrustResolver.metadataTrust(
                for: chainAsset,
                userDefaults: userDefaults
            ).trust == .verified,
            isTestnet: testnets.isTestnet(chain),
            isOnlySelectedNetwork: isOnlySelectedNetwork(chain),
            hasAccount: account != nil && !Self.lacksAppOwnedAccount(chainAsset, wallet: wallet),
            isListedZeroDefault: isListedZeroDefault,
            isPrimaryUtility: isPrimaryUtility(chainAsset),
            isFavouriteNetwork: wallet.favouriteChainIds.contains(chain.chainId),
            isSendVetoed: sendVetoedChainIds.contains(chain.chainId.lowercased()) ||
                Self.isSendPaused(on: chain, wallet: wallet, tonSendReleasePolicy: tonSendReleasePolicy),
            isLegacyZeroHidden: legacyZeroHidden.contains(chainAsset.assetKey),
            offersAccountSetup: offersAccountSetup
        )
    }

    /// Networks this build cannot send from for `wallet`, as `SendDepencyContainer`
    /// routes them: TON for every wallet but a 4.0.4 TON wallet until
    /// `TonProductionSendReleasePolicy` enables it, and the universal-wallet
    /// Iroha networks. Their zero rows would invite deposits that cannot leave.
    static func isSendPaused(
        on chain: ChainModel,
        wallet: MetaAccountModel,
        tonSendReleasePolicy: TonProductionSendReleasePolicy = .production
    ) -> Bool {
        if chain.isTonCompatibilityChain {
            return !tonSendReleasePolicy.isEnabled && wallet.legacyTonAccount == nil
        }

        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.taira.chainId,
             UniversalWalletRegistry.taira.id,
             UniversalWalletRegistry.nexus.chainId,
             UniversalWalletRegistry.nexus.id:
            return true
        default:
            return false
        }
    }

    /// The networks a remote kill switch has paused sending on, as
    /// `sendVetoedChainIds`: Bitcoin and Solana ship with send enabled, and a
    /// paused network never invites deposits with a zero row.
    static func sendVetoedChainIds(bitcoinSendEnabled: Bool, solanaSendEnabled: Bool) -> Set<ChainModel.Id> {
        var chainIds = Set<ChainModel.Id>()
        if !bitcoinSendEnabled {
            chainIds.insert(UniversalWalletRegistry.bitcoinMainnet.chainId)
        }
        if !solanaSendEnabled {
            chainIds.insert(UniversalWalletRegistry.solanaMainnet.chainId)
        }
        return chainIds
    }

    /// The networks `gate` lets nobody send on right now: the compiled release
    /// policy plus remembered remote vetoes, exactly what Send itself checks.
    static func sendVetoedChainIds(gate: UniversalSendGate) -> Set<ChainModel.Id> {
        sendVetoedChainIds(
            bitcoinSendEnabled: gate.isEnabled(.bitcoin),
            solanaSendEnabled: gate.isEnabled(.solana)
        )
    }

    /// Testnets are hidden by default, so their network headers are too,
    /// unless the user picked the testnet as the only network.
    func hidesNetworkByDefault(_ chain: ChainModel) -> Bool {
        testnets.isTestnet(chain) && !isOnlySelectedNetwork(chain)
    }

    /// Bitcoin, Solana and Taira utility assets of a wallet that still needs its
    /// dedicated account and can add it in place. The row routes to the account
    /// setup. Native TON and EVM-only wallets cannot hold these accounts, so they
    /// are never offered one (`UniversalWalletStoredSeedAdopter.canAddAppOwnedAccounts`).
    static func offersAccountSetup(_ chainAsset: ChainAsset, wallet: MetaAccountModel) -> Bool {
        lacksAppOwnedAccount(chainAsset, wallet: wallet) &&
            UniversalWalletStoredSeedAdopter.canAddAppOwnedAccounts(to: wallet)
    }

    /// Bitcoin, Solana and Taira utility assets of a wallet without a valid
    /// dedicated account on that network, whether or not it can add one.
    static func lacksAppOwnedAccount(_ chainAsset: ChainAsset, wallet: MetaAccountModel) -> Bool {
        guard chainAsset.asset.isUtility else {
            return false
        }

        let isAppOwned = UniversalWalletRegistry.bitcoinNetwork(for: chainAsset.chain.chainId) ==
            UniversalWalletRegistry.bitcoinMainnet ||
            UniversalWalletRegistry.solanaNetwork(for: chainAsset.chain.chainId) ==
            UniversalWalletRegistry.solanaMainnet ||
            UniversalWalletChainAccountSupport.chainId(
                chainAsset.chain.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            )

        return isAppOwned && !UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
            in: wallet,
            for: chainAsset.chain.chainId
        )
    }

    private func isOnlySelectedNetwork(_ chain: ChainModel) -> Bool {
        guard case let .chain(chainId) = networkFilter else {
            return false
        }
        return chainId == chain.chainId
    }

    private func isPrimaryUtility(_ chainAsset: ChainAsset) -> Bool {
        let chain = chainAsset.chain
        let primaryId: AssetModel.Id?
        if let cached = primaryUtilityAssetIds[chain.chainId] {
            primaryId = cached
        } else {
            primaryId = PortfolioVisibilityPolicy.primaryUtilityAssetId(of: chain, zeroDefaults: zeroDefaults)
            primaryUtilityAssetIds[chain.chainId] = primaryId
        }
        return primaryId == chainAsset.asset.id
    }
}

// MARK: - Legacy visibility data

/// A read-once snapshot of an AssetKey list stored for one wallet.
struct AssetKeySet: Equatable {
    private let identifiers: Set<String>

    init(identifiers: Set<String>) {
        self.identifiers = identifiers
    }

    var isEmpty: Bool {
        identifiers.isEmpty
    }

    var count: Int {
        identifiers.count
    }

    func contains(_ assetKey: AssetKey) -> Bool {
        identifiers.contains(AssetVisibilityPreferenceStore.storageIdentifier(for: assetKey))
    }
}

/// Resolves legacy `AssetVisibility.assetId` values to catalog assets. 4.0.4
/// wrote `ChainAsset.identifier` ("chainId : assetId"); the Core Data V9 policy
/// turned older `assetIdsEnabled` entries into bare ids.
struct LegacyVisibilityIndex {
    private let chainAssets: [ChainAsset]
    private var byIdentifier: [String: [ChainAsset]] = [:]
    private var byChainAndAssetId: [String: [ChainAsset]] = [:]
    private var byLooseId: [String: [ChainAsset]] = [:]

    init(chainAssets: [ChainAsset]) {
        self.chainAssets = chainAssets
        for chainAsset in chainAssets {
            let asset = chainAsset.asset
            byIdentifier[chainAsset.identifier, default: []].append(chainAsset)
            for assetId in Set([asset.id.lowercased(), asset.canonicalAssetId.lowercased()]) {
                byChainAndAssetId[Self.chainAndAssetId(chainAsset.chain.chainId, assetId), default: []]
                    .append(chainAsset)
            }
            let looseIds = [asset.id, asset.canonicalAssetId, asset.symbol, asset.name].map { $0.lowercased() }
            for looseId in Set(looseIds) {
                byLooseId[looseId, default: []].append(chainAsset)
            }
        }
    }

    /// The asset a 4.0.4 row names: its exact identifier, or the same chain and
    /// asset id written with different spacing or EVM address case.
    func exactMatches(_ legacyAssetId: String) -> [ChainAsset] {
        if let matches = byIdentifier[legacyAssetId] {
            return matches
        }

        let parts = legacyAssetId.components(separatedBy: " : ")
        guard parts.count == 2 else {
            return []
        }

        let chainId = parts[0].trimmingCharacters(in: .whitespaces)
        let assetId = parts[1].trimmingCharacters(in: .whitespaces)
        return (byChainAndAssetId[Self.chainAndAssetId(chainId, assetId.lowercased())] ?? []).filter {
            PortfolioSharedConfigResource.assetIdsMatch(assetId, $0.asset.id, on: $0.chain) ||
                PortfolioSharedConfigResource.assetIdsMatch(assetId, $0.asset.canonicalAssetId, on: $0.chain)
        }
    }

    /// The broad matches older code accepted: a bare asset id, symbol or name.
    /// They can span networks, so they only ever feed the hide-while-zero hint.
    func looseMatches(_ legacyAssetId: String) -> [ChainAsset] {
        byLooseId[legacyAssetId.lowercased()] ?? []
    }

    /// Asset keys the rows hide. Exact rows decide for their asset, and a
    /// visible exact row always wins; loose matches count only for assets no
    /// exact row names.
    func hiddenAssetKeys(for visibilities: [AssetVisibility], allowsBroadMatches: Bool) -> [AssetKey] {
        var exactFlags: [AssetKey: Bool] = [:]
        var looselyHidden = Set<AssetKey>()
        var order: [AssetKey] = []
        var seen = Set<AssetKey>()

        func record(_ assetKey: AssetKey) {
            if seen.insert(assetKey).inserted {
                order.append(assetKey)
            }
        }

        for visibility in visibilities {
            for assetKey in exactMatches(visibility.assetId).map(\.assetKey) {
                exactFlags[assetKey] = (exactFlags[assetKey] ?? true) && visibility.hidden
                record(assetKey)
            }

            guard allowsBroadMatches, visibility.hidden else {
                continue
            }

            for assetKey in looseMatches(visibility.assetId).map(\.assetKey) {
                looselyHidden.insert(assetKey)
                record(assetKey)
            }
        }

        return order.filter { exactFlags[$0] ?? looselyHidden.contains($0) }
    }

    /// What the first migration (TestFlight 2026.9.x) wrote: for every row, an
    /// explicit preference on each asset matching its identifier, asset id,
    /// canonical id, symbol or name, later rows overwriting earlier ones.
    func firstMigrationPreferences(for visibilities: [AssetVisibility]) -> [(AssetKey, AssetPreference)] {
        var written: [AssetKey: AssetPreference] = [:]
        var order: [AssetKey] = []

        for visibility in visibilities {
            let candidates = (byIdentifier[visibility.assetId] ?? []) + looseMatches(visibility.assetId)
            for assetKey in candidates.map(\.assetKey) {
                if written[assetKey] == nil {
                    order.append(assetKey)
                }
                written[assetKey] = visibility.hidden ? .hidden : .shown
            }
        }

        return order.compactMap { assetKey in written[assetKey].map { (assetKey, $0) } }
    }

    /// Assets the TestFlight 2026.9.x scans marked Shown while they were still
    /// Auto (`setDefaultVisibilitiesIfNeeded`): the utility asset of every
    /// ranked network, and SORA Nexus XOR.
    func scanShownAssetKeys() -> [AssetKey] {
        var seen = Set<AssetKey>()

        return chainAssets.filter { chainAsset in
            let chainName = chainAsset.chain.name.lowercased()
            let isPinnedNative = chainAsset.chain.rank != nil && chainAsset.asset.isUtility
            let isSoraNexusXor = chainAsset.asset.isUtility
                && chainAsset.asset.symbol.caseInsensitiveCompare("XOR") == .orderedSame
                && chainName.contains("sora")
                && chainName.contains("nexus")

            return isPinnedNative || isSoraNexusXor
        }
        .map(\.assetKey)
        .filter { seen.insert($0).inserted }
    }

    private static func chainAndAssetId(_ chainId: String, _ assetId: String) -> String {
        [chainId.lowercased(), assetId].joined(separator: "\u{0}")
    }
}
