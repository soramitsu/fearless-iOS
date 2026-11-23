import Foundation
import Observation
import WalletCore

/// How one network's balances fared in the current sync.
enum ChainSyncState: Equatable {
    case syncing
    case synced
    case failed(String)
}

/// Balances and prices of the selected wallet. Each network is fetched on
/// its own, so a network that fails never hides or delays the others.
@MainActor
@Observable
final class PortfolioStore {
    @ObservationIgnored private let services: WalletServices

    private(set) var chains: [Chain] = []
    private(set) var assets: [Asset] = []
    private(set) var catalogLoaded = false
    private(set) var balances: [AssetID: BalanceState] = [:]
    private(set) var prices: [String: AssetPrice] = [:]
    private(set) var priceError: String?
    private(set) var chainSync: [ChainID: ChainSyncState] = [:]
    private(set) var isRefreshing = false
    private(set) var lastUpdated: Date?
    private(set) var walletID: WalletID?
    private(set) var priceCurrency: FiatCurrency?
    @ObservationIgnored private var generation = 0

    init(services: WalletServices) {
        self.services = services
    }

    /// Drops everything that belongs to a wallet (on lock and on wallet switch).
    func reset() {
        generation += 1
        balances = [:]
        prices = [:]
        priceError = nil
        chainSync = [:]
        isRefreshing = false
        lastUpdated = nil
        walletID = nil
        priceCurrency = nil
    }

    func loadCatalogIfNeeded() async {
        guard !catalogLoaded else { return }
        let catalog = services.catalog
        async let chainList = catalog.chains()
        async let assetList = catalog.assets()
        let (loadedChains, loadedAssets) = await (chainList, assetList)
        chains = loadedChains.sorted { $0.sortOrder == $1.sortOrder ? $0.name < $1.name : $0.sortOrder < $1.sortOrder }
        assets = loadedAssets
        catalogLoaded = true
    }

    func chain(_ id: ChainID) -> Chain? {
        chains.first { $0.id == id }
    }

    func asset(_ id: AssetID) -> Asset? {
        assets.first { $0.id == id }
    }

    /// Chains the wallet has an account for.
    func chains(for wallet: Wallet, includeTestnets: Bool) -> [Chain] {
        chains.filter { wallet.ecosystems.contains($0.ecosystem) && (includeTestnets || !$0.isTestnet) }
    }

    /// Fetches balances network by network and prices alongside. Values
    /// already on screen stay until their replacement arrives.
    func refresh(wallet: Wallet, fiat: FiatCurrency, includeTestnets: Bool) async {
        generation += 1
        let current = generation
        if walletID != wallet.id {
            balances = [:]
            chainSync = [:]
            lastUpdated = nil
            walletID = wallet.id
        }
        if priceCurrency != fiat {
            prices = [:]
            priceCurrency = fiat
        }
        isRefreshing = true
        await loadCatalogIfNeeded()
        guard current == generation else { return }

        let wanted = chains(for: wallet, includeTestnets: includeTestnets)
        let wantedIDs = Set(wanted.map(\.id))
        chainSync = chainSync.filter { wantedIDs.contains($0.key) }
        var assetsByChain: [ChainID: [AssetID]] = [:]
        for asset in assets where wantedIDs.contains(asset.chainID) {
            assetsByChain[asset.chainID, default: []].append(asset.id)
            if balances[asset.id]?.balance == nil { balances[asset.id] = .loading }
        }
        for chain in wanted { chainSync[chain.id] = .syncing }

        let priceIDs = Set(assets.filter { wantedIDs.contains($0.chainID) }.compactMap(\.priceID))
        let priceService = services.prices
        let priceTask = Task { () -> Result<[String: AssetPrice], Error> in
            guard !priceIDs.isEmpty else { return .success([:]) }
            do {
                return .success(try await priceService.prices(for: priceIDs, in: fiat))
            } catch {
                return .failure(error)
            }
        }

        let balanceService = services.balances
        let walletID = wallet.id
        await withTaskGroup(of: (ChainID, [AssetID: Result<AssetBalance, WalletError>]).self) { group in
            for (chainID, assetIDs) in assetsByChain {
                group.addTask {
                    (chainID, await balanceService.balances(of: walletID, assets: assetIDs))
                }
            }
            for await (chainID, results) in group {
                guard current == generation else { continue }
                apply(results, requested: assetsByChain[chainID] ?? [], chainID: chainID)
            }
        }
        // A network with no assets in the catalog has nothing to wait for.
        if current == generation {
            for chain in wanted where assetsByChain[chain.id] == nil { chainSync[chain.id] = .synced }
        }

        let priceResult = await priceTask.value
        guard current == generation else { return }
        switch priceResult {
        case .success(let fetched):
            prices = fetched
            priceError = nil
        case .failure(let error):
            priceError = ErrorText.message(for: error)
        }
        isRefreshing = false
        lastUpdated = Date()
    }

    private func apply(_ results: [AssetID: Result<AssetBalance, WalletError>], requested: [AssetID], chainID: ChainID) {
        var failure: String?
        for assetID in requested {
            switch results[assetID] {
            case .success(let balance)?:
                balances[assetID] = .loaded(balance)
            case .failure(let error)?:
                let message = ErrorText.message(for: error)
                failure = failure ?? message
                // Keep the last known balance on screen; the network row says it is stale.
                if balances[assetID]?.balance == nil { balances[assetID] = .failed(message) }
            case nil:
                let message = "No answer for this asset."
                failure = failure ?? message
                if balances[assetID]?.balance == nil { balances[assetID] = .failed(message) }
            }
        }
        chainSync[chainID] = failure.map(ChainSyncState.failed) ?? .synced
    }

    // MARK: Derived

    /// Every asset of the networks the wallet can use, in catalog order.
    func rows(for wallet: Wallet?) -> [AssetRow] {
        guard let wallet else { return [] }
        let chainByID = Dictionary(chains.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return assets.compactMap { asset in
            guard let chain = chainByID[asset.chainID], wallet.ecosystems.contains(chain.ecosystem) else { return nil }
            return AssetRow(
                asset: asset,
                chain: chain,
                balance: balances[asset.id] ?? .loading,
                price: asset.priceID.flatMap { prices[$0] }
            )
        }
        .sorted { lhs, rhs in
            lhs.chain.sortOrder == rhs.chain.sortOrder ? lhs.asset.id.isNative && !rhs.asset.id.isNative : lhs.chain.sortOrder < rhs.chain.sortOrder
        }
    }

    /// Networks asked in this sync, with how many answered and how many gave up.
    var syncCounts: (done: Int, failed: Int, total: Int) {
        var done = 0
        var failed = 0
        for state in chainSync.values {
            switch state {
            case .synced: done += 1
            case .failed: failed += 1
            case .syncing: break
            }
        }
        return (done, failed, chainSync.count)
    }

    var failedChains: [(chain: Chain, message: String)] {
        chains.compactMap { chain in
            if case .failed(let message)? = chainSync[chain.id] { return (chain, message) }
            return nil
        }
    }
}
