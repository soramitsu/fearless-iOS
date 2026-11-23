import DesignSystem
import SwiftUI
import WalletCore

/// The wallet's history in a sortable table, with an inspector for the
/// selected entry.
struct ActivityView: View {
    @Bindable var app: AppModel

    @State private var sortOrder = [KeyPathComparator(\ActivityRow.sortDate, order: .reverse)]
    @State private var kind: ActivityFilter.Kind = .all
    @State private var status: ActivityStatus?

    private var allRows: [ActivityRow] {
        app.activity.rows(assets: app.portfolio.assets, chains: app.portfolio.chains)
    }

    private var rows: [ActivityRow] {
        ActivityFilter(kind: kind, status: status, search: app.searchText, showTestnets: app.settings.showTestnets)
            .apply(to: allRows)
            .sorted(using: sortOrder)
    }

    private var selectedRow: ActivityRow? {
        guard let id = app.selectedActivityID else { return nil }
        return allRows.first { $0.id == id }
    }

    private var inspectorPresented: Binding<Bool> {
        Binding(get: { app.settings.inspectorVisible }, set: { app.settings.inspectorVisible = $0 })
    }

    var body: some View {
        let rows = rows
        VStack(spacing: 0) {
            filterBar(count: rows.count)
            Divider()
            ForEach(unavailable, id: \.id) { entry in
                InlineMessage("\(entry.name): \(entry.message)", kind: .warning) {
                    Button("Retry") { Task { await app.refresh() } }
                        .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                Divider()
            }
            table(rows)
                .overlay {
                    if rows.isEmpty { emptyState }
                }
        }
        // The pane beside an inspector is measured on its own: without an explicit
        // minimum, wrapping text in a banner would inflate its minimum height.
        .frame(minWidth: 380, minHeight: 300)
        .inspector(isPresented: inspectorPresented) {
            ActivityInspector(app: app, row: selectedRow)
                .inspectorColumnWidth(min: 260, ideal: 296, max: 400)
        }
    }

    private var unavailable: [(id: String, name: String, message: String)] {
        app.activity.unavailable
            .map { (id: $0.key.rawValue, name: app.portfolio.chain($0.key)?.name ?? "A network", message: $0.value) }
            .sorted { $0.name < $1.name }
    }

    private func filterBar(count: Int) -> some View {
        HStack(spacing: 12) {
            Picker("Type", selection: $kind) {
                ForEach(ActivityFilter.Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel("Filter by type")
            Picker("Status", selection: $status) {
                Text("Any Status").tag(ActivityStatus?.none)
                Divider()
                Text("Confirmed").tag(ActivityStatus?.some(.success))
                Text("Pending").tag(ActivityStatus?.some(.pending))
                Text("Failed").tag(ActivityStatus?.some(.failed))
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel("Filter by status")
            Spacer()
            if app.activity.state.isLoading {
                ProgressView().controlSize(.small).accessibilityLabel("Loading activity")
            }
            Text(count == 1 ? "1 entry" : "\(count) entries")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func table(_ rows: [ActivityRow]) -> some View {
        Table(rows, selection: $app.selectedActivityID, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.sortDate) { row in
                Text(row.item.timestamp, format: Self.dateFormat(for: row.item.timestamp))
                    .monospacedDigit()
                    .lineLimit(1)
                    .help(row.item.timestamp.formatted(date: .complete, time: .standard))
            }
            .width(min: 100, ideal: 108, max: 170)

            TableColumn("Type", value: \.sortType) { row in
                HStack(spacing: 7) {
                    ActivityTypeIcon(row: row, size: 20)
                    Text(row.typeName).lineLimit(1)
                }
            }
            .width(min: 92, ideal: 116, max: 170)

            TableColumn("Asset", value: \.sortAsset) { row in
                HStack(spacing: 7) {
                    AssetIconView(asset: row.asset, chain: row.chain, size: 20)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.symbol).fontWeight(.medium)
                        Text(row.chain?.name ?? "Unknown network").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
            }
            .width(min: 100, ideal: 120, max: 220)

            TableColumn("Amount", value: \.sortAmount) { row in
                ActivityAmountText(row: row)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 96, ideal: 110, max: 190)

            TableColumn("From / To", value: \.sortCounterparty) { row in
                if let counterparty = row.item.counterparty {
                    AddressChip(counterparty, head: 6, tail: 4, showsCopyButton: false)
                        .accessibilityLabel(row.item.direction == .incoming ? "From" : "To")
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(min: 90, ideal: 98, max: 200)

            TableColumn("Status", value: \.sortStatus) { row in
                StatusPill(row.statusName, kind: row.item.status == .success ? .success : (row.item.status == .failed ? .failed : .pending))
            }
            .width(min: 90, ideal: 96, max: 130)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if let id = ids.first, let row = allRows.first(where: { $0.id == id }) {
                ActivityContextMenu(app: app, row: row)
            }
        } primaryAction: { ids in
            if let id = ids.first {
                app.selectedActivityID = id
                app.settings.inspectorVisible = true
            }
        }
    }

    /// Month, day and time; the year only when it is not this year.
    static func dateFormat(for date: Date) -> Date.FormatStyle {
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        let base = Date.FormatStyle().month(.abbreviated).day().hour().minute()
        return sameYear ? base : base.year()
    }

    @ViewBuilder private var emptyState: some View {
        Group {
            if case .failed(let message) = app.activity.state {
                ErrorStateView("Activity could not be loaded", message: message) {
                    Task { await app.refresh() }
                }
            } else if app.activity.state.isLoading || app.activity.state == .idle {
                LoadingStateView("Loading activity…")
            } else if !app.searchText.isEmpty || kind != .all || status != nil {
                EmptyStateView("No Results", message: "No activity matches the filters.", systemImage: "magnifyingglass") {
                    Button("Clear Filters") {
                        app.searchText = ""
                        kind = .all
                        status = nil
                    }
                }
            } else {
                EmptyStateView("No Activity Yet", message: "Transfers you send and receive appear here.", systemImage: "clock.arrow.circlepath") {
                    Button("Receive…") { app.presentReceive() }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

/// The round direction mark of an activity entry.
struct ActivityTypeIcon: View {
    let row: ActivityRow
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.15))
            Image(systemName: row.typeSymbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var color: Color {
        if row.item.status == .failed { return BrandColor.failure }
        switch row.item.direction {
        case .incoming, .other: return BrandColor.gain
        case .outgoing: return BrandColor.accent
        case .selfTransfer: return .secondary
        }
    }
}

/// The amount of an entry with its sign: plus for incoming, minus for outgoing.
struct ActivityAmountText: View {
    let row: ActivityRow

    var body: some View {
        let digits = Money.displayDigits(isStablecoin: row.asset?.isStablecoin ?? false, decimals: row.item.amount.decimals)
        AmountText(row.item.amount, symbol: row.symbol, minimumFractionDigits: digits.minimum, maximumFractionDigits: max(digits.maximum, 4), sign: sign)
            .foregroundStyle(row.item.status == .failed ? AnyShapeStyle(.secondary) : (isIncoming ? AnyShapeStyle(BrandColor.gain) : AnyShapeStyle(.primary)))
            .strikethrough(row.item.status == .failed)
    }

    private var isIncoming: Bool {
        row.item.direction == .incoming || row.item.direction == .other
    }

    private var sign: AmountText.Sign {
        switch row.item.direction {
        case .incoming, .other: return .plus
        case .outgoing: return .minus
        case .selfTransfer: return .none
        }
    }
}

/// Context menu of an activity row.
struct ActivityContextMenu: View {
    let app: AppModel
    let row: ActivityRow

    var body: some View {
        if let counterparty = row.item.counterparty {
            Button("Copy Address") {
                Clipboard.shared.copy(counterparty)
                app.showToast("Address copied", symbol: "doc.on.doc")
            }
        }
        if let hash = row.item.hash {
            Button("Copy Transaction Hash") {
                Clipboard.shared.copy(hash)
                app.showToast("Transaction hash copied", symbol: "doc.on.doc")
            }
        }
        Divider()
        Button("Send \(row.symbol)…") { app.presentSend(assetID: row.item.assetID) }
            .disabled(app.selectedWallet?.isWatchOnly ?? true)
        if let chain = row.chain {
            Button("Receive on \(chain.name)…") { app.presentReceive(chainID: chain.id) }
        }
        Divider()
        Button("Show in \(row.chain?.explorer?.name ?? "Explorer")") { app.openExplorer(row.item.explorerURL) }
            .disabled(AddressFormat.webURL(row.item.explorerURL) == nil)
    }
}
