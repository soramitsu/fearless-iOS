import DesignSystem
import SwiftUI
import UniformTypeIdentifiers
import WalletCore

/// The wallet: sidebar, the selected section and its inspector.
struct MainView: View {
    @Bindable var app: AppModel

    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(app: app)
                .frame(minHeight: 320)
                .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 320)
        } detail: {
            detail
                // An explicit minimum keeps wrapping text from inflating the
                // column's (and so the window's) minimum height.
                .frame(minWidth: 440, minHeight: 320)
                .navigationTitle(app.section.title)
                .navigationSubtitle(app.selectedWallet?.name ?? "")
                .toolbar { MainToolbar(app: app) }
        }
        .searchable(text: $app.searchText, placement: .toolbar, prompt: searchPrompt)
        .sheet(item: $app.sheet) { route in
            sheetContent(route)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            JSONDrop.handle(providers) { url in app.importJSON(from: url) }
        }
        .onChange(of: app.searchText) { _, text in
            // Search is about assets; typing on the overview moves to the table.
            if !text.isEmpty, app.section == .portfolio { app.section = .assets }
        }
        .onChange(of: app.settings.fiatCode) { _, _ in Task { await app.refresh() } }
        .onChange(of: app.settings.showTestnets) { _, _ in Task { await app.refresh() } }
    }

    private var searchPrompt: String {
        switch app.section {
        case .portfolio, .assets: return "Search assets"
        case .activity: return "Search activity"
        case .networks: return "Search networks"
        }
    }

    @ViewBuilder private var detail: some View {
        if let error = app.walletsError, app.wallets.isEmpty {
            ErrorStateView("Wallets could not be loaded", message: error) {
                Task { await app.loadWallets() }
            }
        } else if app.selectedWallet == nil {
            LoadingStateView("Opening your wallets…")
        } else {
            switch app.section {
            case .portfolio: PortfolioView(app: app)
            case .assets: AssetsView(app: app)
            case .activity: ActivityView(app: app)
            case .networks: NetworksView(app: app)
            }
        }
    }

    @ViewBuilder
    private func sheetContent(_ route: SheetRoute) -> some View {
        switch route {
        case .send(let model):
            SendSheet(model: model) { app.dismissSheet() }
        case .receive(let model):
            ReceiveSheet(model: model, onShowExplorer: { app.openExplorer($0) }) { app.dismissSheet() }
        case .addWallet(let model):
            AddWalletSheet(model: model) { app.dismissSheet() }
        case .backup(let model):
            WalletSecretSheet(model: model) { app.dismissSheet() }
        }
    }
}

/// Toolbar of the main window: total value, Send, Receive, Refresh, privacy and the inspector.
struct MainToolbar: ToolbarContent {
    @Bindable var app: AppModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .status) {
            VStack(spacing: 0) {
                Text("Total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(app.totalValueText)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Total portfolio value")
            .accessibilityValue(app.settings.balancesHidden ? "Hidden" : app.totalValueText)
            .help("Total value of \(app.selectedWallet?.name ?? "this wallet") in \(app.settings.fiat.name)")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                app.presentSend()
            } label: {
                Label("Send", systemImage: "arrow.up.right")
            }
            .help("Send (⇧⌘S)")
            .disabled(app.selectedWallet?.isWatchOnly ?? true)

            Button {
                app.presentReceive()
            } label: {
                Label("Receive", systemImage: "arrow.down.left")
            }
            .help("Receive (⇧⌘R)")
            .disabled(app.selectedWallet == nil)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                Task { await app.refresh() }
            } label: {
                if app.portfolio.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing")
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .help("Refresh balances and activity (⌘R)")
            .disabled(app.portfolio.isRefreshing)

            Toggle(isOn: Binding(get: { app.settings.balancesHidden }, set: { app.settings.balancesHidden = $0 })) {
                Label("Hide Balances", systemImage: app.settings.balancesHidden ? "eye.slash" : "eye")
            }
            .help(app.settings.balancesHidden ? "Show balances (⇧⌘H)" : "Hide balances (⇧⌘H)")

            if app.section != .portfolio {
                Toggle(isOn: Binding(get: { app.settings.inspectorVisible }, set: { app.settings.inspectorVisible = $0 })) {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help(app.settings.inspectorVisible ? "Hide the inspector" : "Show the inspector")
            }
        }
    }
}
