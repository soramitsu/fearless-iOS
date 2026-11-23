import DesignSystem
import SwiftUI
import WalletCore

/// Every asset of the selected wallet in a sortable table, with an
/// inspector for the selected one.
struct AssetsView: View {
    @Bindable var app: AppModel

    @State private var sortOrder = [KeyPathComparator(\AssetRow.sortValue, order: .reverse)]
    @State private var ecosystem: Ecosystem?

    private var allRows: [AssetRow] {
        app.portfolio.rows(for: app.selectedWallet)
    }

    private var rows: [AssetRow] {
        var filter = app.assetFilter
        filter.search = app.searchText
        filter.ecosystem = ecosystem
        return filter.apply(to: allRows).sorted(using: sortOrder)
    }

    private var selectedRow: AssetRow? {
        guard let id = app.selectedAssetID else { return nil }
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
            ForEach(app.portfolio.failedChains, id: \.chain.id) { failure in
                InlineMessage("\(failure.chain.name): \(failure.message)", kind: .warning) {
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
            AssetInspector(app: app, row: selectedRow)
                .inspectorColumnWidth(min: 260, ideal: 296, max: 400)
        }
    }

    private func filterBar(count: Int) -> some View {
        HStack(spacing: 12) {
            if (app.selectedWallet?.ecosystems.count ?? 0) > 1 {
                Picker("Networks", selection: $ecosystem) {
                    Text("All").tag(Ecosystem?.none)
                    Text("Polkadot").tag(Ecosystem?.some(.substrate))
                    Text("Ethereum & EVM").tag(Ecosystem?.some(.evm))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("Filter by ecosystem")
            }
            Toggle("Hide zero balances", isOn: Binding(
                get: { app.settings.hideZeroBalances },
                set: { app.settings.hideZeroBalances = $0 }
            ))
            .toggleStyle(.checkbox)
            Spacer()
            Text(count == 1 ? "1 asset" : "\(count) assets")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func table(_ rows: [AssetRow]) -> some View {
        Table(rows, selection: $app.selectedAssetID, sortOrder: $sortOrder) {
            TableColumn("Asset", value: \.sortSymbol) { row in
                HStack(spacing: 9) {
                    AssetIconView(asset: row.asset, chain: row.chain, size: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.asset.symbol).fontWeight(.semibold)
                        Text(row.asset.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.asset.symbol), \(row.asset.name)")
            }
            .width(min: 104, ideal: 124)

            TableColumn("Network", value: \.sortNetwork) { row in
                HStack(spacing: 6) {
                    ChainIconView(name: row.chain.name, iconName: row.chain.iconName, accentHex: row.chain.accentHex, size: 16)
                    Text(row.chain.name).lineLimit(1)
                    if row.chain.isTestnet {
                        StatusPill("Testnet", kind: .testnet, showsIcon: false)
                    }
                }
            }
            .width(min: 104, ideal: 148)

            TableColumn("Price", value: \.sortPrice) { row in
                FiatText(row.price?.value, currency: app.settings.fiat, isPrivate: false)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 66, ideal: 78, max: 130)

            TableColumn("24h", value: \.sortChange) { row in
                ChangeText(percent: row.price?.change24h)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 64, ideal: 70, max: 110)

            TableColumn("Balance", value: \.sortBalance) { row in
                BalanceCell(row: row)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 96, ideal: 116, max: 190)

            TableColumn("Value", value: \.sortValue) { row in
                FiatText(row.fiatValue, currency: app.settings.fiat)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 84, ideal: 94, max: 170)
        }
        .contextMenu(forSelectionType: AssetID.self) { ids in
            if let id = ids.first, let row = allRows.first(where: { $0.id == id }) {
                AssetContextMenu(app: app, row: row)
            }
        } primaryAction: { ids in
            if let id = ids.first {
                app.selectedAssetID = id
                app.settings.inspectorVisible = true
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if allRows.isEmpty {
            LoadingStateView("Loading assets…")
                .background(Color(nsColor: .controlBackgroundColor))
        } else if !app.searchText.isEmpty {
            EmptyStateView("No Results", message: "No asset matches “\(app.searchText)”.", systemImage: "magnifyingglass") {
                Button("Clear Search") { app.searchText = "" }
            }
            .background(Color(nsColor: .controlBackgroundColor))
        } else {
            EmptyStateView("No Assets to Show", message: "Zero balances and hidden assets are filtered out. Change that in the bar above or in Settings.", systemImage: "circle.hexagongrid") {
                Button("Show Zero Balances") { app.settings.hideZeroBalances = false }
            }
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

/// The balance column: the amount, a spinner while it loads, or why it failed.
struct BalanceCell: View {
    let row: AssetRow

    var body: some View {
        switch row.balance {
        case .loading:
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel("Loading balance")
        case .failed(let message):
            Label("Unavailable", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(BrandColor.warning)
                .help(message)
                .accessibilityLabel("Balance unavailable: \(message)")
        case .loaded(let balance):
            AmountText(balance.total, symbol: row.asset.symbol, minimumFractionDigits: row.displayDigits.minimum, maximumFractionDigits: row.displayDigits.maximum)
        }
    }
}

/// Context menu of an asset row.
struct AssetContextMenu: View {
    let app: AppModel
    let row: AssetRow

    var body: some View {
        Button("Copy \(row.chain.name) Address") {
            Task { await app.copyAddress(on: row.chain) }
        }
        Divider()
        Button("Send \(row.asset.symbol)…") { app.presentSend(assetID: row.id) }
            .disabled(app.selectedWallet?.isWatchOnly ?? true)
        Button("Receive on \(row.chain.name)…") { app.presentReceive(chainID: row.chain.id) }
        Divider()
        Button("Show in \(row.chain.explorer?.name ?? "Explorer")") {
            Task { await app.showAccountInExplorer(on: row.chain) }
        }
        .disabled(row.chain.explorer?.accountURLTemplate == nil)
        Divider()
        Button("Hide \(row.asset.symbol) on \(row.chain.name)") { app.hideAsset(row.id) }
    }
}
