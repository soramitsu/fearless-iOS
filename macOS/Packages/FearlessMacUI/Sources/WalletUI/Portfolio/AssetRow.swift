import Foundation
import WalletCore

/// What the app knows about one asset's balance right now.
enum BalanceState: Equatable {
    case loading
    case loaded(AssetBalance)
    case failed(String)

    var balance: AssetBalance? {
        if case .loaded(let balance) = self { return balance }
        return nil
    }

    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

/// One line of the assets table: an asset on a network with its balance,
/// price and value. Sort keys are plain values so table columns can sort.
struct AssetRow: Identifiable, Equatable {
    let asset: Asset
    let chain: Chain
    var balance: BalanceState
    var price: AssetPrice?

    var id: AssetID { asset.id }

    var total: TokenAmount? { balance.balance?.total }
    var transferable: TokenAmount? { balance.balance?.transferable }
    var locked: TokenAmount? { balance.balance?.locked }

    /// Fiat value of the whole balance; nil without a balance or a price.
    var fiatValue: Decimal? {
        guard let total, let price else { return nil }
        return total.fiatValue(unitPrice: price.value)
    }

    var hasBalance: Bool {
        guard let total else { return false }
        return !total.isZero
    }

    // Sort keys.
    var sortSymbol: String { asset.symbol.lowercased() + " " + chain.name.lowercased() }
    var sortNetwork: String { chain.name.lowercased() + " " + asset.symbol.lowercased() }
    var sortPrice: Decimal { price?.value ?? -1 }
    var sortChange: Decimal { price?.change24h ?? -1_000_000 }
    var sortBalance: Decimal { total?.decimalValue ?? -1 }
    var sortValue: Decimal { fiatValue ?? -1 }

    /// Fraction digits to show for this asset's amounts.
    var displayDigits: (minimum: Int, maximum: Int) {
        if asset.isStablecoin { return (min(2, asset.decimals), min(2, asset.decimals)) }
        return (0, min(4, asset.decimals))
    }

    func matches(_ query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return asset.symbol.lowercased().contains(needle)
            || asset.name.lowercased().contains(needle)
            || chain.name.lowercased().contains(needle)
    }
}

/// Which rows the lists show.
struct AssetFilter: Equatable {
    var hideZeroBalances = false
    var showTestnets = false
    var hiddenAssetKeys: Set<String> = []
    var search = ""
    var ecosystem: Ecosystem?

    func apply(to rows: [AssetRow]) -> [AssetRow] {
        rows.filter { row in
            if !showTestnets, row.chain.isTestnet { return false }
            if hiddenAssetKeys.contains(row.id.description) { return false }
            if let ecosystem, row.chain.ecosystem != ecosystem { return false }
            if hideZeroBalances, case .loaded(let balance) = row.balance, balance.total.isZero { return false }
            return row.matches(search)
        }
    }
}

/// Totals and breakdowns of a set of rows. Testnet assets carry no price,
/// so they never count.
struct PortfolioSummary: Equatable {
    struct Slice: Identifiable, Equatable {
        let id: String
        let name: String
        let value: Decimal
        let share: Decimal
        let accentHex: String?
        let iconName: String?
        let symbol: String?
    }

    let total: Decimal
    /// Value 24 hours ago, from each asset's own change.
    let previousTotal: Decimal
    let pricedRowCount: Int
    let byNetwork: [Slice]
    let byAsset: [Slice]
    let topHoldings: [AssetRow]

    var change: Decimal { total - previousTotal }

    /// 24-hour change in percent; nil when there is nothing to compare.
    var changePercent: Decimal? {
        guard previousTotal > 0 else { return nil }
        return (total - previousTotal) / previousTotal * 100
    }

    init(rows: [AssetRow], topCount: Int = 5) {
        var total: Decimal = 0
        var previous: Decimal = 0
        var priced = 0
        var networks: [ChainID: (chain: Chain, value: Decimal)] = [:]
        var assets: [String: (name: String, value: Decimal, iconName: String?)] = [:]
        for row in rows {
            guard let value = row.fiatValue else { continue }
            priced += 1
            total += value
            let change = row.price?.change24h ?? 0
            let divisor = 1 + change / 100
            previous += divisor > 0 ? value / divisor : value
            networks[row.chain.id, default: (row.chain, 0)].value += value
            assets[row.asset.symbol, default: (row.asset.name, 0, row.asset.iconName)].value += value
        }
        self.total = total
        previousTotal = previous
        pricedRowCount = priced
        let whole = total > 0 ? total : 1
        byNetwork = networks.values
            .filter { $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.chain.sortOrder < $1.chain.sortOrder : $0.value > $1.value }
            .map { Slice(id: $0.chain.id.rawValue, name: $0.chain.name, value: $0.value, share: $0.value / whole, accentHex: $0.chain.accentHex, iconName: $0.chain.iconName, symbol: nil) }
        byAsset = assets
            .filter { $0.value.value > 0 }
            .sorted { $0.value.value == $1.value.value ? $0.key < $1.key : $0.value.value > $1.value.value }
            .map { Slice(id: $0.key, name: $0.key, value: $0.value.value, share: $0.value.value / whole, accentHex: nil, iconName: $0.value.iconName, symbol: $0.key) }
        topHoldings = Array(
            rows.filter { ($0.fiatValue ?? 0) > 0 }
                .sorted { ($0.fiatValue ?? 0) == ($1.fiatValue ?? 0) ? $0.sortSymbol < $1.sortSymbol : ($0.fiatValue ?? 0) > ($1.fiatValue ?? 0) }
                .prefix(topCount)
        )
    }
}
