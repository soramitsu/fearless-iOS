import DesignSystem
import SwiftUI
import WalletCore

/// The overview: total value, how it is split, the largest holdings, the
/// state of each network and the latest activity.
struct PortfolioView: View {
    let app: AppModel

    var body: some View {
        let summary = app.summary
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let wallet = app.selectedWallet, app.needsBackup(wallet) {
                    BackupBanner(walletName: wallet.name) { app.presentBackup(for: wallet) }
                }
                PortfolioHero(app: app, summary: summary)
                if let priceError = app.portfolio.priceError {
                    InlineMessage("Prices are unavailable: \(priceError)", kind: .warning, boxed: true) {
                        Button("Retry") { Task { await app.refresh() } }
                            .controlSize(.small)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        AllocationCard(app: app, summary: summary)
                            .frame(minWidth: 340)
                        TopHoldingsCard(app: app, summary: summary)
                            .frame(minWidth: 340)
                    }
                    VStack(spacing: 16) {
                        AllocationCard(app: app, summary: summary)
                        TopHoldingsCard(app: app, summary: summary)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        NetworkStatusCard(app: app)
                            .frame(minWidth: 340)
                        RecentActivityCard(app: app)
                            .frame(minWidth: 340)
                    }
                    VStack(spacing: 16) {
                        NetworkStatusCard(app: app)
                        RecentActivityCard(app: app)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 1240)
            .frame(maxWidth: .infinity)
        }
    }
}

/// A reminder that stays until the wallet's phrase is backed up.
struct BackupBanner: View {
    let walletName: String
    let action: () -> Void

    var body: some View {
        InlineMessage("“\(walletName)” is not backed up. If this Mac is lost or erased, only the recovery phrase can restore it.", kind: .warning, boxed: true) {
            Button("Back Up Now", action: action)
        }
    }
}

/// The brand card with the total, its 24-hour change and the sync dial.
struct PortfolioHero: View {
    let app: AppModel
    let summary: PortfolioSummary

    @Environment(\.balancesHidden) private var hidden
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            background
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOTAL BALANCE")
                        .font(.caption.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(BrandPalette.textMuted)
                    Text(app.totalValueText)
                        .font(.system(size: 48, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(BrandPalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : BrandMotion.glide(BrandMotion.d510), value: app.totalValueText)
                        .accessibilityLabel("Total balance")
                        .accessibilityValue(hidden ? "Hidden" : app.totalValueText)
                    changeLine
                    Spacer(minLength: 8)
                    syncLine
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 0) {
                    CrestMark(size: 60)
                        .foregroundStyle(BrandPalette.gold)
                        .padding(.top, 2)
                        .padding(.trailing, 6)
                    Spacer(minLength: 8)
                    HStack(spacing: 10) {
                        Button {
                            app.presentSend()
                        } label: {
                            Label("Send", systemImage: "arrow.up.right")
                                .frame(minWidth: 76)
                        }
                        .brandProminentButton()
                        .disabled(app.selectedWallet?.isWatchOnly ?? true)
                        Button {
                            app.presentReceive()
                        } label: {
                            Label("Receive", systemImage: "arrow.down.left")
                                .frame(minWidth: 76)
                        }
                    }
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(LitRim.gradient, lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [BrandPalette.night, BrandPalette.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(
                stops: [
                    .init(color: Color(hex: 0xFF7A2E).opacity(0.42), location: 0),
                    .init(color: Color(hex: 0xE0126E).opacity(0.30), location: 0.3),
                    .init(color: Color(hex: 0x4A1160).opacity(0.25), location: 0.66),
                    .init(color: .clear, location: 1)
                ],
                center: UnitPoint(x: 0.92, y: 0.0),
                startRadius: 0,
                endRadius: 520
            )
            AsanohaPattern(cell: 26).opacity(0.05)
            RegistrationMarks()
        }
    }

    @ViewBuilder private var changeLine: some View {
        if let percent = summary.changePercent, summary.pricedRowCount > 0 {
            HStack(spacing: 6) {
                Image(systemName: summary.change < 0 ? "arrow.down.right" : "arrow.up.right")
                    .font(.caption.weight(.bold))
                if !hidden {
                    Text(signedFiat(summary.change))
                        .monospacedDigit()
                }
                Text("(" + Money.percent(percent) + ")")
                    .monospacedDigit()
                Text("24h")
                    .foregroundStyle(BrandPalette.textMuted)
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(summary.change < 0 ? Color(hex: 0xFF9A52) : BrandPalette.cyan)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Change in 24 hours")
            .accessibilityValue((summary.change < 0 ? "Down " : "Up ") + Money.percent(abs(percent)))
        } else if app.portfolio.isRefreshing {
            Text("Loading balances…")
                .font(.callout)
                .foregroundStyle(BrandPalette.textMuted)
        } else {
            Text(" ").font(.callout)
        }
    }

    private func signedFiat(_ value: Decimal) -> String {
        let text = Money.fiat(abs(value), currency: app.settings.fiat)
        return (value < 0 ? "−" : "+") + text
    }

    private var syncLine: some View {
        let counts = app.portfolio.syncCounts
        let syncing = counts.total > 0 && counts.done + counts.failed < counts.total
        return HStack(spacing: 8) {
            SyncDial(done: counts.done, failed: counts.failed, total: counts.total, size: 18)
            if syncing {
                Text("\(counts.done + counts.failed) / \(counts.total)")
                    .monospacedDigit()
                    .foregroundStyle(BrandPalette.cyan)
            } else if counts.failed > 0 {
                Text(counts.failed == 1 ? "Live · 1 network unavailable" : "Live · \(counts.failed) networks unavailable")
                    .foregroundStyle(BrandPalette.textSoft)
            } else if let updated = app.portfolio.lastUpdated {
                Text("Live · updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(BrandPalette.textSoft)
            } else {
                Text("Waiting for networks")
                    .foregroundStyle(BrandPalette.textMuted)
            }
        }
        .font(.callout)
    }
}

/// How the value splits by asset or by network: a thin segmented bar above
/// a list that names each part with its share and value.
struct AllocationCard: View {
    enum Grouping: String, CaseIterable, Identifiable {
        case asset = "Assets"
        case network = "Networks"

        var id: String { rawValue }
    }

    let app: AppModel
    let summary: PortfolioSummary

    @State private var grouping: Grouping = .asset
    @Environment(\.balancesHidden) private var hidden

    private struct Entry: Identifiable {
        let id: String
        let name: String
        let value: Decimal
        let share: Decimal
        let color: Color
        let slice: PortfolioSummary.Slice?
    }

    /// Parts in catalog order, so a colour stays with its asset or network.
    private var entries: [Entry] {
        let slices = grouping == .asset ? summary.byAsset : summary.byNetwork
        let order: [String]
        switch grouping {
        case .asset:
            var seen: Set<String> = []
            order = app.portfolio.assets.filter { $0.priceID != nil }.map(\.symbol).filter { seen.insert($0).inserted }
        case .network:
            order = app.portfolio.chains.filter { !$0.isTestnet }.map(\.id.rawValue)
        }
        var named: [Entry] = []
        var otherValue: Decimal = 0
        var otherShare: Decimal = 0
        let byID = Dictionary(slices.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (slot, id) in order.enumerated() {
            guard let slice = byID[id] else { continue }
            if let color = ChartPalette.color(slot: slot) {
                named.append(Entry(id: slice.id, name: slice.name, value: slice.value, share: slice.share, color: color, slice: slice))
            } else {
                otherValue += slice.value
                otherShare += slice.share
            }
        }
        for slice in slices where !order.contains(slice.id) {
            otherValue += slice.value
            otherShare += slice.share
        }
        if otherValue > 0 {
            named.append(Entry(id: "other", name: "Other", value: otherValue, share: otherShare, color: ChartPalette.other, slice: nil))
        }
        return named
    }

    var body: some View {
        let entries = entries
        VStack(alignment: .leading, spacing: 12) {
            CardHeader("Allocation") {
                Picker("Group by", selection: $grouping) {
                    ForEach(Grouping.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
                .accessibilityLabel("Group allocation by")
            }
            if entries.isEmpty {
                Text(app.portfolio.isRefreshing ? "Loading balances…" : "Nothing with a price to show yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                SegmentedShareBar(parts: entries.map { entry in
                    SegmentedShareBar.Part(
                        id: entry.id,
                        fraction: NSDecimalNumber(decimal: entry.share).doubleValue,
                        color: entry.color,
                        summary: partSummary(entry)
                    )
                })
                VStack(spacing: 7) {
                    ForEach(entries) { entry in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(entry.color)
                                .frame(width: 10, height: 10)
                                .accessibilityHidden(true)
                            Text(entry.name)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(Money.share(entry.share))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 56, alignment: .trailing)
                            FiatText(entry.value, currency: app.settings.fiat)
                                .frame(width: 104, alignment: .trailing)
                        }
                        .font(.callout)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(partSummary(entry))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func partSummary(_ entry: Entry) -> String {
        let share = Money.share(entry.share)
        if hidden { return "\(entry.name): \(share)" }
        return "\(entry.name): \(Money.fiat(entry.value, currency: app.settings.fiat)), \(share)"
    }
}

/// The largest holdings, ranked, each with a bar on one baseline.
struct TopHoldingsCard: View {
    let app: AppModel
    let summary: PortfolioSummary

    var body: some View {
        let rows = summary.topHoldings
        let largest = rows.first?.fiatValue ?? 1
        VStack(alignment: .leading, spacing: 12) {
            CardHeader("Top Holdings") {
                Button("All Assets") { app.section = .assets }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColor.accent)
                    .font(.callout)
            }
            if rows.isEmpty {
                Text(app.portfolio.isRefreshing ? "Loading balances…" : "No holdings with a price yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                VStack(spacing: 9) {
                    ForEach(rows) { row in
                        Button {
                            app.selectedAssetID = row.id
                            app.section = .assets
                        } label: {
                            HoldingRow(row: row, fraction: fraction(row.fiatValue, of: largest), fiat: app.settings.fiat)
                        }
                        .buttonStyle(.plain)
                        .help("Show \(row.asset.symbol) on \(row.chain.name) in Assets")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func fraction(_ value: Decimal?, of largest: Decimal) -> Double {
        guard let value, largest > 0 else { return 0 }
        return min(1, max(0, NSDecimalNumber(decimal: value / largest).doubleValue))
    }
}

/// One ranked holding: icon, name, amount and value over a thin bar.
struct HoldingRow: View {
    let row: AssetRow
    let fraction: Double
    let fiat: FiatCurrency

    var body: some View {
        HStack(spacing: 10) {
            AssetIconView(asset: row.asset, chain: row.chain, size: 28, showsNetworkBadge: true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.asset.symbol).font(.callout.weight(.semibold))
                    Text(row.chain.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 6)
                    if let total = row.total {
                        AmountText(total, symbol: nil, minimumFractionDigits: row.displayDigits.minimum, maximumFractionDigits: row.displayDigits.maximum)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    FiatText(row.fiatValue, currency: fiat)
                        .font(.callout.weight(.medium))
                        .frame(minWidth: 84, alignment: .trailing)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule().fill(BrandColor.accent).frame(width: max(3, proxy.size.width * fraction))
                    }
                }
                .frame(height: 4)
                .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Every network the wallet reads from, with what happened in this sync.
/// A failing network is reported here and never blocks the others.
struct NetworkStatusCard: View {
    let app: AppModel

    var body: some View {
        let chains = app.selectedWallet.map { app.portfolio.chains(for: $0, includeTestnets: app.settings.showTestnets) } ?? []
        VStack(alignment: .leading, spacing: 12) {
            CardHeader("Networks") {
                Button("Manage") { app.section = .networks }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColor.accent)
                    .font(.callout)
            }
            if chains.isEmpty {
                Text("Loading networks…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    ForEach(chains) { chain in
                        NetworkStatusRow(chain: chain, state: app.portfolio.chainSync[chain.id]) {
                            Task { await app.refresh() }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct NetworkStatusRow: View {
    let chain: Chain
    let state: ChainSyncState?
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                ChainIconView(name: chain.name, iconName: chain.iconName, accentHex: chain.accentHex, size: 20)
                Text(chain.name).font(.callout).lineLimit(1)
                if chain.isTestnet {
                    StatusPill("Testnet", kind: .testnet, showsIcon: false)
                }
                Spacer(minLength: 8)
                switch state {
                case .synced?:
                    StatusPill("Synced", kind: .success)
                case .syncing?:
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text("Syncing").font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Syncing")
                case .failed?:
                    Button("Retry", action: retry)
                        .controlSize(.mini)
                    StatusPill("Unavailable", kind: .failed)
                case nil:
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            if case .failed(let message)? = state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(BrandColor.failure)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The latest few movements with a way to the full table.
struct RecentActivityCard: View {
    let app: AppModel

    var body: some View {
        let rows = Array(
            ActivityFilter(showTestnets: app.settings.showTestnets)
                .apply(to: app.activity.rows(assets: app.portfolio.assets, chains: app.portfolio.chains))
                .prefix(6)
        )
        VStack(alignment: .leading, spacing: 12) {
            CardHeader("Recent Activity") {
                Button("All Activity") { app.section = .activity }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColor.accent)
                    .font(.callout)
            }
            if rows.isEmpty {
                Group {
                    if app.activity.state.isLoading {
                        Text("Loading activity…")
                    } else if let error = app.activity.state.errorMessage {
                        Text(error)
                    } else {
                        Text("No activity yet.")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                VStack(spacing: 9) {
                    ForEach(rows) { row in
                        Button {
                            app.selectedActivityID = row.id
                            app.section = .activity
                        } label: {
                            RecentActivityRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct RecentActivityRow: View {
    let row: ActivityRow

    var body: some View {
        HStack(spacing: 10) {
            ActivityTypeIcon(row: row, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.typeName).font(.callout.weight(.medium)).lineLimit(1)
                Text(row.item.timestamp, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if row.item.status != .success {
                StatusPill(row.statusName, kind: row.item.status == .failed ? .failed : .pending)
            }
            ActivityAmountText(row: row)
                .font(.callout)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
