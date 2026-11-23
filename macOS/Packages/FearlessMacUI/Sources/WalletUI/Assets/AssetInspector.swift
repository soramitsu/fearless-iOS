import DesignSystem
import SwiftUI
import WalletCore

/// Details of the selected asset: balance breakdown, price, the wallet's
/// address on that network and the actions.
struct AssetInspector: View {
    let app: AppModel
    let row: AssetRow?

    var body: some View {
        if let row {
            AssetInspectorContent(app: app, row: row)
        } else {
            ContentUnavailableView("No Asset Selected", systemImage: "circle.hexagongrid", description: Text("Select an asset to see its balance, address and actions."))
        }
    }
}

private struct AssetInspectorContent: View {
    let app: AppModel
    let row: AssetRow

    @State private var address: ReceiveModel.AddressState = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                actions
                balanceSection
                priceSection
                addressSection
                detailsSection
                Button("Hide This Asset") { app.hideAsset(row.id) }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColor.accent)
                    .font(.callout)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: "\(row.chain.id.rawValue)|\(app.selectedWalletID?.description ?? "")") {
            await loadAddress()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AssetIconView(asset: row.asset, chain: row.chain, size: 44, showsNetworkBadge: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.asset.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(row.asset.symbol) on \(row.chain.name)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if row.chain.isTestnet {
                        StatusPill("Testnet", kind: .testnet, showsIcon: false)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                app.presentSend(assetID: row.id)
            } label: {
                Label("Send", systemImage: "arrow.up.right").frame(maxWidth: .infinity)
            }
            .brandProminentButton()
            .disabled(app.selectedWallet?.isWatchOnly ?? true)
            Button {
                app.presentReceive(chainID: row.chain.id)
            } label: {
                Label("Receive", systemImage: "arrow.down.left").frame(maxWidth: .infinity)
            }
        }
        .controlSize(.large)
    }

    private var balanceSection: some View {
        InspectorSection("Balance") {
            switch row.balance {
            case .loading:
                HStack(spacing: 8) {
                    CometLoader(size: 20)
                    Text("Loading balance…").foregroundStyle(.secondary)
                }
            case .failed(let message):
                InlineMessage(message, kind: .warning) {
                    Button("Retry") { Task { await app.refresh() } }.controlSize(.small)
                }
            case .loaded(let balance):
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        FiatText(row.fiatValue, currency: app.settings.fiat, placeholder: "No price")
                            .font(.title2.weight(.bold))
                        AmountText(balance.total, symbol: row.asset.symbol, maximumFractionDigits: min(8, row.asset.decimals))
                            .foregroundStyle(.secondary)
                    }
                    if !balance.locked.isZero {
                        BalanceSplitBar(transferable: balance.transferable, locked: balance.locked)
                    }
                    InspectorRow("Transferable") {
                        AmountText(balance.transferable, symbol: row.asset.symbol, maximumFractionDigits: min(8, row.asset.decimals))
                    }
                    InspectorRow("Locked") {
                        AmountText(balance.locked, symbol: row.asset.symbol, maximumFractionDigits: min(8, row.asset.decimals))
                    }
                    .help("Reserved, frozen or staked. It cannot be sent until it is released.")
                    InspectorRow("Total") {
                        AmountText(balance.total, symbol: row.asset.symbol, maximumFractionDigits: min(8, row.asset.decimals))
                    }
                    Text("Updated \(balance.updatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var priceSection: some View {
        InspectorSection("Market") {
            if let price = row.price {
                InspectorRow("Price") {
                    FiatText(price.value, currency: app.settings.fiat, isPrivate: false)
                }
                InspectorRow("24 hours") {
                    ChangeText(percent: price.change24h)
                }
            } else {
                Text(row.asset.priceID == nil ? "This asset has no price feed." : "Price not loaded.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var addressSection: some View {
        InspectorSection("Your \(row.chain.name) Address") {
            switch address {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading address…").foregroundStyle(.secondary)
                }
            case .failed(let message):
                InlineMessage(message, kind: .error) {
                    Button("Retry") { Task { await loadAddress() } }.controlSize(.small)
                }
            case .loaded(let value):
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        QRCodeView(value)
                            .frame(width: 92, height: 92)
                            .onTapGesture { app.presentReceive(chainID: row.chain.id) }
                            .help("Open Receive for a larger code")
                        FullAddressText(value)
                    }
                    HStack(spacing: 8) {
                        Button {
                            Clipboard.shared.copy(value)
                            app.showToast("\(row.chain.name) address copied", symbol: "doc.on.doc")
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        if let url = AddressFormat.webURL(row.chain.explorer?.accountURL(address: value)) {
                            Button {
                                app.openExplorer(url)
                            } label: {
                                Label(row.chain.explorer?.name ?? "Explorer", systemImage: "arrow.up.forward.square")
                            }
                            .help("Show this address in \(row.chain.explorer?.name ?? "the explorer")")
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var detailsSection: some View {
        InspectorSection("Details") {
            InspectorRow("Type") {
                Text(kindText)
            }
            if case .erc20(let contract) = row.asset.kind {
                InspectorRow("Contract") { AddressChip(contract, head: 6, tail: 4) }
            }
            if case .substrateAsset(let id) = row.asset.kind {
                InspectorRow("Asset ID") { Text(id).monospacedDigit() }
            }
            InspectorRow("Decimals") { Text("\(row.asset.decimals)").monospacedDigit() }
            if let deposit = row.asset.existentialDeposit, !deposit.isZero {
                InspectorRow("Minimum balance") {
                    Text(Money.token(deposit, symbol: row.asset.symbol, maximumFractionDigits: 6))
                        .monospacedDigit()
                }
                .help("An account holding less than this is removed by the network.")
            }
        }
    }

    private var kindText: String {
        switch row.asset.kind {
        case .native: return "Native token"
        case .erc20: return "ERC-20 token"
        case .substrateAsset: return "Asset Hub token"
        }
    }

    private func loadAddress() async {
        guard let wallet = app.selectedWallet else { return }
        address = .loading
        do {
            address = .loaded(try await app.services.wallets.address(of: wallet.id, on: row.chain.id))
        } catch {
            address = .failed(ErrorText.message(for: error))
        }
    }
}

/// A titled group in an inspector.
struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 7) {
                content
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 12)
        }
    }
}

/// A label and its value on one line.
struct InspectorRow<Value: View>: View {
    let label: String
    let value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            value
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Transferable against locked, as two segments of one bar.
struct BalanceSplitBar: View {
    let transferable: TokenAmount
    let locked: TokenAmount

    var body: some View {
        let free = NSDecimalNumber(decimal: transferable.decimalValue).doubleValue
        let held = NSDecimalNumber(decimal: locked.decimalValue).doubleValue
        VStack(alignment: .leading, spacing: 5) {
            SegmentedShareBar(parts: [
                .init(id: "transferable", fraction: free, color: BrandColor.accent, summary: "Transferable"),
                .init(id: "locked", fraction: held, color: Color.primary.opacity(0.28), summary: "Locked")
            ], height: 6)
            HStack(spacing: 12) {
                legend(color: BrandColor.accent, text: "Transferable")
                legend(color: Color.primary.opacity(0.28), text: "Locked")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}
