import DesignSystem
import SwiftUI
import WalletCore

/// Details of the selected activity entry.
struct ActivityInspector: View {
    let app: AppModel
    let row: ActivityRow?

    var body: some View {
        if let row {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(row)
                    InspectorSection("Transfer") {
                        InspectorRow("Status") {
                            StatusPill(row.statusName, kind: row.item.status == .success ? .success : (row.item.status == .failed ? .failed : .pending))
                        }
                        InspectorRow("Date") {
                            Text(row.item.timestamp, format: Date.FormatStyle(date: .long, time: .standard))
                                .monospacedDigit()
                        }
                        InspectorRow("Network") {
                            HStack(spacing: 5) {
                                if let chain = row.chain {
                                    ChainIconView(name: chain.name, iconName: chain.iconName, accentHex: chain.accentHex, size: 14)
                                }
                                Text(row.chain?.name ?? "Unknown")
                            }
                        }
                        if let fee = row.item.fee {
                            InspectorRow("Network fee") {
                                AmountText(fee, symbol: feeSymbol(for: row), maximumFractionDigits: 8)
                            }
                        }
                    }
                    if let counterparty = row.item.counterparty {
                        InspectorSection(row.item.direction == .incoming ? "From" : "To") {
                            FullAddressText(counterparty)
                            CopyButtonRow(title: "Copy Address", value: counterparty)
                        }
                    }
                    if let hash = row.item.hash {
                        InspectorSection("Transaction") {
                            Text(hash)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(3)
                                .truncationMode(.middle)
                                .accessibilityLabel("Transaction hash")
                                .accessibilityValue(hash)
                            HStack(spacing: 8) {
                                CopyButtonRow(title: "Copy Hash", value: hash)
                                if AddressFormat.webURL(row.item.explorerURL) != nil {
                                    Button {
                                        app.openExplorer(row.item.explorerURL)
                                    } label: {
                                        Label(row.chain?.explorer?.name ?? "Explorer", systemImage: "arrow.up.forward.square")
                                    }
                                    .controlSize(.small)
                                    .help("Show this transfer in \(row.chain?.explorer?.name ?? "the explorer")")
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("No Entry Selected", systemImage: "clock.arrow.circlepath", description: Text("Select a transfer to see its addresses, fee and transaction hash."))
        }
    }

    private func header(_ row: ActivityRow) -> some View {
        HStack(spacing: 12) {
            ActivityTypeIcon(row: row, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.typeName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ActivityAmountText(row: row)
                    .font(.title3.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Fees are paid in the network's native token.
    private func feeSymbol(for row: ActivityRow) -> String {
        guard let chain = row.chain, let native = app.portfolio.asset(chain.nativeAssetID) else { return row.symbol }
        return native.symbol
    }
}

/// A small labelled copy button for inspectors.
struct CopyButtonRow: View {
    let title: String
    let value: String

    @State private var copied = false

    var body: some View {
        Button {
            Clipboard.shared.copy(value)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            Label(copied ? "Copied" : title, systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .controlSize(.small)
    }
}
