import DesignSystem
import SwiftUI
import WalletCore

/// The networks the app reads from: their state in the current sync and,
/// in the inspector, the node each one uses.
struct NetworksView: View {
    @Bindable var app: AppModel

    private var chains: [Chain] {
        let needle = app.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return app.portfolio.chains.filter { chain in
            (app.settings.showTestnets || !chain.isTestnet)
                && (needle.isEmpty || chain.name.lowercased().contains(needle))
        }
    }

    private var selectedChain: Chain? {
        app.portfolio.chains.first { $0.id == app.selectedNetworkID }
    }

    private var inspectorPresented: Binding<Bool> {
        Binding(get: { app.settings.inspectorVisible }, set: { app.settings.inspectorVisible = $0 })
    }

    var body: some View {
        let chains = chains
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle("Show testnets", isOn: Binding(
                    get: { app.settings.showTestnets },
                    set: { app.settings.showTestnets = $0 }
                ))
                .toggleStyle(.checkbox)
                Spacer()
                Text(chains.count == 1 ? "1 network" : "\(chains.count) networks")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .controlSize(.small)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Divider()
            Table(chains, selection: $app.selectedNetworkID) {
                TableColumn("Network") { chain in
                    HStack(spacing: 8) {
                        ChainIconView(name: chain.name, iconName: chain.iconName, accentHex: chain.accentHex, size: 24)
                        Text(chain.name).fontWeight(.medium).lineLimit(1)
                        if chain.isTestnet {
                            StatusPill("Testnet", kind: .testnet, showsIcon: false)
                        }
                    }
                    .padding(.vertical, 3)
                }
                .width(min: 180, ideal: 230)
                TableColumn("Ecosystem") { chain in
                    Text(chain.ecosystem.displayName).foregroundStyle(.secondary)
                }
                .width(min: 120, ideal: 150)
                TableColumn("Assets") { chain in
                    Text(symbols(of: chain)).foregroundStyle(.secondary).lineLimit(1)
                }
                .width(min: 100, ideal: 160)
                TableColumn("Status") { chain in
                    statusView(chain)
                }
                .width(min: 110, ideal: 130)
            }
            .overlay {
                if chains.isEmpty {
                    if app.portfolio.catalogLoaded {
                        EmptyStateView("No Networks", message: "No network matches the search.", systemImage: "magnifyingglass")
                            .background(Color(nsColor: .controlBackgroundColor))
                    } else {
                        LoadingStateView("Loading networks…")
                            .background(Color(nsColor: .controlBackgroundColor))
                    }
                }
            }
        }
        // The pane beside an inspector is measured on its own: without an explicit
        // minimum, wrapping text in a banner would inflate its minimum height.
        .frame(minWidth: 380, minHeight: 300)
        .inspector(isPresented: inspectorPresented) {
            NetworkInspector(app: app, chain: selectedChain)
                .inspectorColumnWidth(min: 270, ideal: 310, max: 420)
        }
        .task(id: app.selectedNetworkID) {
            await app.networkNodes.load(selectedChain)
        }
    }

    private func symbols(of chain: Chain) -> String {
        app.portfolio.assets.filter { $0.chainID == chain.id }.map(\.symbol).joined(separator: ", ")
    }

    @ViewBuilder
    private func statusView(_ chain: Chain) -> some View {
        if let wallet = app.selectedWallet, !wallet.ecosystems.contains(chain.ecosystem) {
            Text("No account").foregroundStyle(.tertiary)
                .help("\(wallet.name) has no \(chain.ecosystem.displayName) account")
        } else {
            switch app.portfolio.chainSync[chain.id] {
            case .synced?:
                StatusPill("Synced", kind: .success)
            case .syncing?:
                StatusPill("Syncing", kind: .pending)
            case .failed(let message)?:
                StatusPill("Unavailable", kind: .failed).help(message)
            case nil:
                Text("—").foregroundStyle(.tertiary)
            }
        }
    }
}

/// Details of the selected network and its nodes.
struct NetworkInspector: View {
    let app: AppModel
    let chain: Chain?

    var body: some View {
        if let chain {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ChainIconView(name: chain.name, iconName: chain.iconName, accentHex: chain.accentHex, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chain.name).font(.title3.weight(.semibold))
                            Text(chain.ecosystem.displayName).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    if case .failed(let message)? = app.portfolio.chainSync[chain.id] {
                        InlineMessage(message, kind: .warning, boxed: true) {
                            Button("Retry") { Task { await app.refresh() } }
                                .controlSize(.small)
                        }
                    }

                    InspectorSection("Node") {
                        NodesEditorView(model: app.networkNodes)
                    }

                    InspectorSection("Details") {
                        if let prefix = chain.ss58Prefix {
                            InspectorRow("Address prefix") { Text("\(prefix)").monospacedDigit() }
                        }
                        if let chainID = chain.evmChainID {
                            InspectorRow("Chain ID") { Text("\(chainID)").monospacedDigit() }
                        }
                        InspectorRow("Explorer") { Text(chain.explorer?.name ?? "None") }
                        InspectorRow("Kind") { Text(chain.isTestnet ? "Test network" : "Main network") }
                    }

                    HStack(spacing: 8) {
                        Button("Receive on \(chain.name)…") { app.presentReceive(chainID: chain.id) }
                            .disabled(!(app.selectedWallet?.ecosystems.contains(chain.ecosystem) ?? false))
                        Button("Copy Address") { Task { await app.copyAddress(on: chain) } }
                            .disabled(!(app.selectedWallet?.ecosystems.contains(chain.ecosystem) ?? false))
                    }
                    .controlSize(.small)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("No Network Selected", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Select a network to choose its node or add your own."))
        }
    }
}
