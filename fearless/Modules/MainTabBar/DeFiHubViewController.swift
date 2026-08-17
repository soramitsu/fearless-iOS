import UIKit
import BigInt
import SoraKeystore
import SSFModels
import SSFPools

enum DeFiFeature: CaseIterable, Hashable {
    case staking
    case nominationPools
    case liquidityPools
    case farming
    case polkamarkt
}

enum DeFiCapabilityState: Equatable {
    case available
    case unavailable(reason: String)

    var isAvailable: Bool {
        if case .available = self {
            return true
        }

        return false
    }

    var reason: String? {
        if case let .unavailable(reason) = self {
            return reason
        }

        return nil
    }
}

struct DeFiCapability: Equatable {
    let feature: DeFiFeature
    let title: String
    let subtitle: String
    let state: DeFiCapabilityState
}

enum DeFiHubPositionRowKind: Equatable {
    case position
    case status
    case empty
    case loading
}

struct DeFiHubPositionRow: Equatable {
    let id: String
    let feature: DeFiFeature?
    let kind: DeFiHubPositionRowKind
    let title: String
    let subtitle: String
    let assetKeys: [AssetKey]

    init(
        id: String,
        feature: DeFiFeature?,
        kind: DeFiHubPositionRowKind,
        title: String,
        subtitle: String,
        assetKeys: [AssetKey] = []
    ) {
        self.id = id
        self.feature = feature
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.assetKeys = assetKeys
    }

    static let loadingPositions = DeFiHubPositionRow(
        id: "positions:loading",
        feature: nil,
        kind: .loading,
        title: "Loading positions…",
        subtitle: "Checking native SORA and indexed DeFi positions."
    )
}

protocol DeFiPositionSourceLoading {
    var feature: DeFiFeature { get }
    var title: String { get }

    func loadPositions() async throws -> [DeFiHubPositionRow]
}

extension DeFiPositionSourceLoading {
    var sourceId: String { "\(feature):\(title)" }
}

struct DeFiPositionsSnapshot: Equatable {
    let rows: [DeFiHubPositionRow]
    let hasPositivePositions: Bool
    let hasPartialFailure: Bool
}

final class DeFiPositionsAggregator {
    private let sources: [DeFiPositionSourceLoading]
    private let explicitlyUnavailableRows: [DeFiHubPositionRow]
    private var lastKnownBySource: [String: [DeFiHubPositionRow]] = [:]

    init(
        sources: [DeFiPositionSourceLoading],
        explicitlyUnavailableRows: [DeFiHubPositionRow]
    ) {
        self.sources = sources
        self.explicitlyUnavailableRows = explicitlyUnavailableRows
    }

    func load() async -> DeFiPositionsSnapshot {
        var positions: [DeFiHubPositionRow] = []
        var statuses = explicitlyUnavailableRows
        var hasFailure = false

        for source in sources {
            do {
                let loaded = try await source.loadPositions()
                let sourcePositions = loaded.filter {
                    $0.kind == .position
                }
                let sourceStatuses = loaded.filter { $0.kind == .status }
                lastKnownBySource[source.sourceId] = sourcePositions
                positions.append(contentsOf: sourcePositions)
                statuses.append(contentsOf: sourceStatuses)
                hasFailure = hasFailure || sourceStatuses.isNotEmpty
            } catch {
                hasFailure = true
                let cached = lastKnownBySource[source.sourceId] ?? []
                positions.append(contentsOf: cached)
                statuses.append(
                    DeFiHubPositionRow(
                        id: "status:\(source.feature):\(cached.isEmpty ? "unavailable" : "stale")",
                        feature: source.feature,
                        kind: .status,
                        title: cached.isEmpty ? "\(source.title) positions unavailable" : "\(source.title) positions are stale",
                        subtitle: cached.isEmpty
                            ? error.localizedDescription
                            : "Showing the last successful result. Refresh failed: \(error.localizedDescription)"
                    )
                )
            }
        }

        positions.sort { ($0.title, $0.id) < ($1.title, $1.id) }
        statuses.sort { ($0.title, $0.id) < ($1.title, $1.id) }
        if positions.isEmpty {
            positions.append(
                DeFiHubPositionRow(
                    id: "positions:empty",
                    feature: nil,
                    kind: .empty,
                    title: "No active DeFi positions",
                    subtitle: "Connected staking, nomination-pool, SORA liquidity, Demeter, and Polkamarkt providers returned no positive positions."
                )
            )
        }

        return DeFiPositionsSnapshot(
            rows: positions + statuses,
            hasPositivePositions: positions.contains { $0.kind == .position },
            hasPartialFailure: hasFailure
        )
    }
}

enum DeFiPositionRowFactory {
    static func liquidityPools(
        _ positions: [AccountPool],
        chain: ChainModel
    ) throws -> [DeFiHubPositionRow] {
        try positions.compactMap { position in
            guard position.chainId.caseInsensitiveCompare(chain.chainId) == .orderedSame else {
                throw SoraLiquidityPoolPositionError.identityMismatch(poolId: position.poolId)
            }

            let baseAsset = try exactAsset(position.baseAssetId, chain: chain)
            let targetAsset = try exactAsset(position.targetAssetId, chain: chain)
            guard baseAsset.assetKey != targetAsset.assetKey else {
                throw SoraLiquidityPoolPositionError.identityMismatch(poolId: position.poolId)
            }
            guard let baseBalance = position.baseAssetPooled,
                  let targetBalance = position.targetAssetPooled,
                  let share = position.accountPoolShare,
                  baseBalance >= .zero,
                  targetBalance >= .zero,
                  share >= .zero else {
                throw SoraLiquidityPoolPositionError.balanceUnavailable(poolId: position.poolId)
            }
            guard baseBalance > .zero || targetBalance > .zero || share > .zero else {
                return nil
            }

            let baseKey = baseAsset.assetKey
            let targetKey = targetAsset.assetKey
            let baseSymbol = baseAsset.asset.symbolUppercased
            let targetSymbol = targetAsset.asset.symbolUppercased
            let canonicalPair = "\(shortAssetId(baseKey.assetId)) / \(shortAssetId(targetKey.assetId))"

            return DeFiHubPositionRow(
                id: [
                    "liquidity-pool",
                    canonicalComponent(baseKey),
                    canonicalComponent(targetKey),
                    lengthPrefixed(position.poolId),
                    lengthPrefixed(position.accountId)
                ].joined(separator: "|"),
                feature: .liquidityPools,
                kind: .position,
                title: "\(baseSymbol) / \(targetSymbol) liquidity",
                subtitle: "Pooled \(decimalString(baseBalance)) \(baseSymbol) · \(decimalString(targetBalance)) \(targetSymbol) · \(decimalString(share))% share · \(chain.name) \(canonicalPair)",
                assetKeys: [baseKey, targetKey]
            )
        }
    }

    static func demeter(
        _ positions: [DemeterAccountPosition],
        chain: ChainModel
    ) -> [DeFiHubPositionRow] {
        positions.filter(\.isActive).map { position in
            let poolSymbol = DemeterFormatting.symbol(for: position.identity.poolAssetId, in: chain)
            let rewardSymbol = DemeterFormatting.symbol(for: position.identity.rewardAssetId, in: chain)
            let action = position.identity.isFarm ? "Farm" : "Stake"
            return DeFiHubPositionRow(
                id: [
                    "demeter",
                    position.identity.baseAssetId,
                    position.identity.poolAssetId,
                    position.identity.rewardAssetId,
                    String(position.identity.isFarm)
                ].joined(separator: ":"),
                feature: .farming,
                kind: .position,
                title: "\(action) \(poolSymbol)",
                subtitle: "Deposited \(DemeterFormatting.naturalString(position.pooledTokens, assetId: position.identity.poolAssetId, chain: chain)) · Rewards \(DemeterFormatting.naturalString(position.rewards, assetId: position.identity.rewardAssetId, chain: chain)) \(rewardSymbol)"
            )
        }
    }

    static func polkamarkt(_ positions: [PolkamarktPosition]) -> [DeFiHubPositionRow] {
        positions.filter {
            (BigUInt($0.shares, radix: 10) ?? .zero) > .zero ||
                (BigUInt($0.netCollateralPaid, radix: 10) ?? .zero) > .zero
        }.map { position in
            DeFiHubPositionRow(
                id: "polkamarkt:\(position.id)",
                feature: .polkamarkt,
                kind: .position,
                title: "Market #\(position.marketId) · \(position.outcome.uppercased())",
                subtitle: "\(PolkamarktMarketDetailViewController.natural(position.shares)) shares · \(position.status)"
            )
        }
    }

    static func staking(
        _ locks: StakingLocks,
        chainAsset: ChainAsset,
        feature: DeFiFeature
    ) -> [DeFiHubPositionRow] {
        guard locks.total > .zero else { return [] }

        let symbol = chainAsset.asset.symbolUppercased
        let values: [(String, Decimal)] = [
            ("staked", locks.staked),
            ("unstaking", locks.unstaking),
            ("redeemable", locks.redeemable),
            ("claimable", locks.claimable ?? .zero)
        ]
        let summary = values.compactMap { label, value in
            value > .zero ? "\(NSDecimalNumber(decimal: value).stringValue) \(symbol) \(label)" : nil
        }.joined(separator: " · ")
        let title = feature == .nominationPools
            ? "\(chainAsset.chain.name) nomination pool"
            : "\(chainAsset.chain.name) staking"

        return [
            DeFiHubPositionRow(
                id: [
                    feature == .nominationPools ? "nomination-pool" : "staking",
                    chainAsset.assetKey.chainId,
                    chainAsset.assetKey.assetId
                ].joined(separator: ":"),
                feature: feature,
                kind: .position,
                title: title,
                subtitle: summary
            )
        ]
    }

    private static func exactAsset(_ assetId: String, chain: ChainModel) throws -> ChainAsset {
        let matches = chain.chainAssets.filter {
            $0.asset.canonicalAssetId.caseInsensitiveCompare(assetId) == .orderedSame
        }
        guard matches.count == 1, let match = matches.first else {
            throw SoraLiquidityPoolPositionError.assetUnavailable(assetId: assetId)
        }
        return match
    }

    private static func canonicalComponent(_ key: AssetKey) -> String {
        [key.ecosystem, key.chainId, key.assetId]
            .map(lengthPrefixed)
            .joined(separator: ":")
    }

    private static func lengthPrefixed(_ value: String) -> String {
        "\(value.utf8.count)#\(value)"
    }

    private static func shortAssetId(_ assetId: String) -> String {
        guard assetId.count > 18 else { return assetId }
        return "\(assetId.prefix(10))…\(assetId.suffix(6))"
    }

    private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

enum SoraLiquidityPoolPositionError: LocalizedError, Equatable {
    case snapshotUnavailable
    case assetUnavailable(assetId: String)
    case identityMismatch(poolId: String)
    case balanceUnavailable(poolId: String)

    var errorDescription: String? {
        switch self {
        case .snapshotUnavailable:
            return "SORA returned no authoritative liquidity-position snapshot."
        case let .assetUnavailable(assetId):
            return "The SORA registry cannot identify exactly one pool asset for \(assetId)."
        case let .identityMismatch(poolId):
            return "SORA returned an invalid canonical asset identity for pool \(poolId)."
        case let .balanceUnavailable(poolId):
            return "The authoritative pooled balances are unavailable for SORA pool \(poolId)."
        }
    }
}

protocol SoraLiquidityPoolPositionLoading {
    func loadPositions(accountId: Data) async throws -> [AccountPool]
}

struct NativeSoraLiquidityPoolPositionLoader: SoraLiquidityPoolPositionLoading {
    let service: PolkaswapLiquidityPoolService

    func loadPositions(accountId: Data) async throws -> [AccountPool] {
        let snapshots = try await service.subscribeUserPools(accountId: accountId)
        for await snapshot in snapshots {
            guard let positions = snapshot.value else {
                throw SoraLiquidityPoolPositionError.snapshotUnavailable
            }
            return positions
        }
        throw SoraLiquidityPoolPositionError.snapshotUnavailable
    }
}

struct SoraLiquidityPoolDeFiPositionSource: DeFiPositionSourceLoading {
    let feature: DeFiFeature = .liquidityPools
    let title = "Liquidity pools"
    let chain: ChainModel
    let accountId: Data
    let loader: SoraLiquidityPoolPositionLoading

    func loadPositions() async throws -> [DeFiHubPositionRow] {
        let positions = try await loader.loadPositions(accountId: accountId)
        return try DeFiPositionRowFactory.liquidityPools(positions, chain: chain)
    }
}

private enum StakingDeFiPositionSourceError: LocalizedError {
    case accountUnavailable
    case runtimeUnavailable

    var errorDescription: String? {
        switch self {
        case .accountUnavailable:
            return "The wallet has no account for this network."
        case .runtimeUnavailable:
            return "The network runtime is unavailable."
        }
    }
}

private struct NativeStakingDeFiPositionSource: DeFiPositionSourceLoading {
    let feature: DeFiFeature = .staking
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    var title: String { "\(chainAsset.chain.name) staking" }

    func loadPositions() async throws -> [DeFiHubPositionRow] {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            throw StakingDeFiPositionSourceError.accountUnavailable
        }
        guard let fetcher = BalanceLocksFetchingFactory.buildBalanceLocksFetcher(for: chainAsset) else {
            throw StakingDeFiPositionSourceError.runtimeUnavailable
        }
        let locks = try await fetcher.fetchStakingLocks(for: accountId)
        return DeFiPositionRowFactory.staking(
            locks,
            chainAsset: chainAsset,
            feature: feature
        )
    }
}

private struct NominationPoolDeFiPositionSource: DeFiPositionSourceLoading {
    let feature: DeFiFeature = .nominationPools
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    var title: String { "\(chainAsset.chain.name) nomination pool" }

    func loadPositions() async throws -> [DeFiHubPositionRow] {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            throw StakingDeFiPositionSourceError.accountUnavailable
        }
        guard let fetcher = BalanceLocksFetchingFactory.buildBalanceLocksFetcher(for: chainAsset) else {
            throw StakingDeFiPositionSourceError.runtimeUnavailable
        }
        let locks = try await fetcher.fetchNominationPoolLocks(for: accountId)
        return DeFiPositionRowFactory.staking(
            locks,
            chainAsset: chainAsset,
            feature: feature
        )
    }
}

private struct DemeterDeFiPositionSource: DeFiPositionSourceLoading {
    let feature: DeFiFeature = .farming
    let title = "Demeter"
    let service: DemeterRuntimeService

    func loadPositions() async throws -> [DeFiHubPositionRow] {
        let snapshot = try await service.snapshot()
        return DeFiPositionRowFactory.demeter(snapshot.positions, chain: service.chain)
    }
}

private struct PolkamarktDeFiPositionSource: DeFiPositionSourceLoading {
    let feature: DeFiFeature = .polkamarkt
    let title = "Polkamarkt"
    let service: PolkamarktLiveService

    func loadPositions() async throws -> [DeFiHubPositionRow] {
        let activity = try await service.indexedActivityResult()
        return DeFiPositionRowFactory.polkamarkt(activity.positions)
    }
}

final class DeFiHubViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case positions
        case opportunities

        var title: String {
            switch self {
            case .positions:
                return "Your positions"
            case .opportunities:
                return "Explore DeFi"
            }
        }
    }

    private let wallet: MetaAccountModel
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var capabilities: [DeFiCapability] = []
    private let injectedPositionsAggregator: DeFiPositionsAggregator?
    private lazy var positionsAggregator = injectedPositionsAggregator ?? makePositionsAggregator()
    private var positionRows: [DeFiHubPositionRow] = [.loadingPositions]
    private var positionsTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        positionsAggregator: DeFiPositionsAggregator? = nil
    ) {
        self.wallet = wallet
        injectedPositionsAggregator = positionsAggregator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "DeFi"
        view.backgroundColor = R.color.colorBlack19()
        configureTableView()
        capabilities = buildCapabilities()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        capabilities = buildCapabilities()
        tableView.reloadData()
        reloadPositions()
    }

    deinit {
        positionsTask?.cancel()
    }

    func showStaking() {
        guard let staking = capabilities.first(where: { $0.feature == .staking }) else {
            return
        }

        open(staking)
    }

    func openPolkamarkt(marketId: String? = nil) {
        guard let soraChain = ChainRegistryFacade.sharedRegistry.availableChains.first(where: {
            $0.chainId == PolkamarktConstants.soraChainId
        }) else {
            presentUnavailable(
                DeFiCapability(
                    feature: .polkamarkt,
                    title: "Polkamarkt",
                    subtitle: "SORA prediction markets using KUSD and XOR fees",
                    state: .unavailable(reason: "SORA Mainnet is not available in the current registry.")
                )
            )
            return
        }
        let controller = PolkamarktMarketListViewController(
            wallet: wallet,
            chain: soraChain,
            marketId: marketId
        )
        controller.hidesBottomBarWhenPushed = false
        navigationController?.pushViewController(controller, animated: true)
    }

    private func configureTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = R.color.colorBlurSeparator()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DeFiCapabilityCell")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func buildCapabilities() -> [DeFiCapability] {
        let chains = ChainRegistryFacade.sharedRegistry.availableChains
        let stakingChains = chains.filter { $0.assets.contains { $0.staking != nil } }
        let poolChains = chains.filter { $0.options?.contains(.poolStaking) == true }
        let stakingState = signingState(
            for: stakingChains,
            missingNetworkReason: "No supported native staking network is available.",
            missingAccountReason: "No staking-capable account is available in this wallet."
        )
        let poolsState = signingState(
            for: poolChains,
            missingNetworkReason: "No supported nomination-pool network is available.",
            missingAccountReason: "No nomination-pool account is available in this wallet."
        )
        let soraChain = chains.first { $0.chainId == PolkamarktConstants.soraChainId }
        let soraState = signingState(
            for: soraChain.map { [$0] } ?? [],
            missingNetworkReason: "SORA Mainnet is not available in the current registry.",
            missingAccountReason: "Add a SORA account to use this feature."
        )
        let soraRuntimeAvailable = soraChain.map {
            ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: $0.chainId) != nil &&
                ChainRegistryFacade.sharedRegistry.getConnection(for: $0.chainId) != nil
        } ?? false
        let soraMutationState: DeFiCapabilityState = {
            guard soraState.isAvailable else { return soraState }
            return soraRuntimeAvailable
                ? .available
                : .unavailable(reason: "The SORA runtime is unavailable. Reconnect before submitting actions.")
        }()

        return [
            DeFiCapability(
                feature: .staking,
                title: "Staking",
                subtitle: "Native staking across supported networks",
                state: stakingState
            ),
            DeFiCapability(
                feature: .nominationPools,
                title: "Nomination pools",
                subtitle: "Join or manage pooled staking positions",
                state: poolsState
            ),
            DeFiCapability(
                feature: .liquidityPools,
                title: "Liquidity pools",
                subtitle: ReviewedLiquidityPoolExecutionAuthority.isAvailable
                    ? "Supply and manage Polkaswap liquidity on SORA"
                    : "Browse SORA pools · supply and remove actions are currently unavailable",
                state: soraMutationState
            ),
            DeFiCapability(
                feature: .farming,
                title: "Farming",
                subtitle: "Demeter farming positions and rewards on SORA",
                state: soraMutationState
            ),
            DeFiCapability(
                feature: .polkamarkt,
                title: "Polkamarkt",
                subtitle: "SORA prediction markets using KUSD and XOR fees",
                state: soraChain == nil
                    ? .unavailable(reason: "SORA Mainnet is not available in the current registry.")
                    : .available
            )
        ]
    }

    private func signingState(
        for chains: [ChainModel],
        missingNetworkReason: String,
        missingAccountReason: String
    ) -> DeFiCapabilityState {
        guard chains.isNotEmpty else {
            return .unavailable(reason: missingNetworkReason)
        }

        let accounts = chains.compactMap { chain -> (ChainModel, ChainAccountResponse)? in
            wallet.fetch(for: chain.accountRequest()).map { (chain, $0) }
        }
        guard accounts.isNotEmpty else {
            return .unavailable(reason: missingAccountReason)
        }

        let canSign = accounts.contains { entry in
            let (chain, account) = entry
            let accountId = account.isChainAccount ? account.accountId : nil
            let keyTag = chain.keystoreTag(metaId: wallet.metaId, accountId: accountId)
            return (try? Keychain().checkKey(for: keyTag)) == true
        }
        return canSign
            ? .available
            : .unavailable(
                reason: "This wallet is watch-only or uses unsupported hardware/external signing for this action."
            )
    }

    private func makePositionsAggregator() -> DeFiPositionsAggregator {
        let chains = ChainRegistryFacade.sharedRegistry.availableChains
        let soraChain = chains.first { $0.chainId == PolkamarktConstants.soraChainId }
        var sources: [DeFiPositionSourceLoading] = []
        var unavailable: [DeFiHubPositionRow] = []

        let nativeStakingAssets = chains.flatMap { chain in
            chain.chainAssets.filter {
                $0.asset.staking != nil &&
                    chain.hasStakingRewardHistory &&
                    wallet.fetch(for: chain.accountRequest()) != nil
            }
        }
        if nativeStakingAssets.isEmpty {
            unavailable.append(
                unavailablePositionRow(
                    feature: .staking,
                    title: "Staking positions unavailable",
                    reason: "No wallet account has an authoritative native-staking position provider."
                )
            )
        } else {
            sources.append(contentsOf: nativeStakingAssets.map {
                NativeStakingDeFiPositionSource(chainAsset: $0, wallet: wallet)
            })
        }

        let nominationPoolAssets = chains.compactMap { chain -> ChainAsset? in
            guard chain.options?.contains(.poolStaking) == true,
                  wallet.fetch(for: chain.accountRequest()) != nil else {
                return nil
            }
            return chain.utilityChainAssets().first
        }
        if nominationPoolAssets.isEmpty {
            unavailable.append(
                unavailablePositionRow(
                    feature: .nominationPools,
                    title: "Nomination-pool positions unavailable",
                    reason: "No wallet account has an authoritative nomination-pool provider."
                )
            )
        } else {
            sources.append(contentsOf: nominationPoolAssets.map {
                NominationPoolDeFiPositionSource(chainAsset: $0, wallet: wallet)
            })
        }

        if let soraChain,
           let accountId = wallet.fetch(for: soraChain.accountRequest())?.accountId {
            let service = PolkaswapLiquidityPoolServiceAssembly.buildService(
                for: soraChain,
                chainRegistry: ChainRegistryFacade.sharedRegistry
            )
            sources.append(
                SoraLiquidityPoolDeFiPositionSource(
                    chain: soraChain,
                    accountId: accountId,
                    loader: NativeSoraLiquidityPoolPositionLoader(service: service)
                )
            )
        } else {
            unavailable.append(
                unavailablePositionRow(
                    feature: .liquidityPools,
                    title: "Liquidity-pool positions unavailable",
                    reason: soraChain == nil
                        ? "SORA Mainnet is not available in the current registry."
                        : "Add a SORA account to load liquidity-pool positions."
                )
            )
        }

        if let soraChain, let demeter = DemeterRuntimeService(wallet: wallet, chain: soraChain) {
            sources.append(DemeterDeFiPositionSource(service: demeter))
        } else {
            unavailable.append(
                unavailablePositionRow(
                    feature: .farming,
                    title: "Demeter positions unavailable",
                    reason: "Add a SORA account and connect to the SORA runtime to load farming positions."
                )
            )
        }
        if let soraChain, soraChain.externalApi?.history?.url != nil {
            sources.append(
                PolkamarktDeFiPositionSource(
                    service: PolkamarktLiveService(wallet: wallet, chain: soraChain)
                )
            )
        } else {
            unavailable.append(
                unavailablePositionRow(
                    feature: .polkamarkt,
                    title: "Polkamarkt positions unavailable",
                    reason: "The SORA account indexer is unavailable; public market browse remains available."
                )
            )
        }
        return DeFiPositionsAggregator(
            sources: sources,
            explicitlyUnavailableRows: unavailable
        )
    }

    private func unavailablePositionRow(
        feature: DeFiFeature,
        title: String,
        reason: String
    ) -> DeFiHubPositionRow {
        DeFiHubPositionRow(
            id: "status:\(feature):unsupported",
            feature: feature,
            kind: .status,
            title: title,
            subtitle: reason
        )
    }

    private func reloadPositions() {
        positionsTask?.cancel()
        positionRows = [.loadingPositions]
        tableView.reloadSections(IndexSet(integer: Section.positions.rawValue), with: .none)
        positionsTask = Task { [weak self] in
            guard let self else { return }
            let snapshot = await positionsAggregator.load()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.positionRows = snapshot.rows
                self.tableView.reloadSections(IndexSet(integer: Section.positions.rawValue), with: .automatic)
            }
        }
    }

    private func open(_ capability: DeFiCapability) {
        guard capability.state.isAvailable else {
            presentUnavailable(capability)
            return
        }

        let controller: UIViewController?
        switch capability.feature {
        case .staking:
            controller = StakingMainViewFactory.createView(moduleOutput: nil)?.controller
        case .nominationPools:
            controller = StakingPoolMainAssembly.configureModule(moduleOutput: nil)?.view.controller
        case .liquidityPools:
            guard let soraChain = ChainRegistryFacade.sharedRegistry.availableChains.first(where: { $0.isSora }) else {
                presentUnavailable(capability)
                return
            }
            controller = LiquidityPoolsOverviewAssembly.configureModule(
                wallet: wallet,
                chainId: soraChain.chainId
            )?.view.controller
        case .farming:
            guard let soraChain = ChainRegistryFacade.sharedRegistry.availableChains.first(where: {
                $0.chainId == PolkamarktConstants.soraChainId
            }) else {
                presentUnavailable(capability)
                return
            }
            controller = DemeterFarmingViewController(wallet: wallet, chain: soraChain)
        case .polkamarkt:
            openPolkamarkt()
            return
        }

        guard let controller else {
            presentUnavailable(
                DeFiCapability(
                    feature: capability.feature,
                    title: capability.title,
                    subtitle: capability.subtitle,
                    state: .unavailable(reason: "The required network service is currently unavailable. Try again after the network reconnects.")
                )
            )
            return
        }

        controller.hidesBottomBarWhenPushed = false
        navigationController?.pushViewController(controller, animated: true)
    }

    private func presentUnavailable(_ capability: DeFiCapability) {
        let alert = UIAlertController(
            title: capability.title,
            message: capability.state.reason,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension DeFiHubViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section) == .positions ? positionRows.count : capabilities.count
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeFiCapabilityCell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.textProperties.color = R.color.colorWhite() ?? .white
        configuration.secondaryTextProperties.color = R.color.colorLightGray() ?? .lightGray

        if Section(rawValue: indexPath.section) == .positions {
            let row = positionRows[indexPath.row]
            configuration.text = row.title
            configuration.secondaryText = row.subtitle
            configuration.image = row.kind == .position
                ? image(for: row.feature ?? .staking)
                : UIImage(systemName: row.kind == .loading ? "arrow.triangle.2.circlepath" : "info.circle")
            let canOpen = row.feature.flatMap { feature in
                capabilities.first { $0.feature == feature }?.state.isAvailable
            } == true
            cell.accessoryType = canOpen ? .disclosureIndicator : .none
            cell.selectionStyle = canOpen ? .default : .none
        } else {
            let capability = capabilities[indexPath.row]
            configuration.text = capability.title
            configuration.secondaryText = capability.state.reason ?? capability.subtitle
            configuration.image = image(for: capability.feature)
            cell.accessoryType = capability.state.isAvailable ? .disclosureIndicator : .none
            cell.selectionStyle = .default
        }

        cell.contentConfiguration = configuration
        cell.backgroundColor = R.color.colorWhite8()
        return cell
    }

    private func image(for feature: DeFiFeature) -> UIImage? {
        switch feature {
        case .staking:
            return UIImage(systemName: "seal")
        case .nominationPools:
            return UIImage(systemName: "person.3")
        case .liquidityPools:
            return UIImage(systemName: "drop.triangle")
        case .farming:
            return UIImage(systemName: "leaf")
        case .polkamarkt:
            return UIImage(systemName: "chart.xyaxis.line")
        }
    }
}

extension DeFiHubViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .positions,
           let feature = positionRows[safe: indexPath.row]?.feature,
           let capability = capabilities.first(where: { $0.feature == feature }) {
            open(capability)
            return
        }
        guard Section(rawValue: indexPath.section) == .opportunities else {
            return
        }

        open(capabilities[indexPath.row])
    }
}
