import DesignSystem
import SwiftUI
import WalletCore

/// The wallet's address on one network as a large QR code and as text.
struct ReceiveSheet: View {
    let model: ReceiveModel
    let onShowExplorer: (URL) -> Void
    let onClose: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                WalletAvatar(wallet: model.wallet, size: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Receive").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("To \(model.wallet.name)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                networkPicker
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            Divider()

            VStack(spacing: 14) {
                content
                InlineMessage(model.warning, kind: .warning, boxed: true)
            }
            .padding(20)
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()
            HStack {
                if let url = model.explorerURL {
                    Button {
                        onShowExplorer(url)
                    } label: {
                        Label(model.chain?.explorer?.name ?? "Explorer", systemImage: "arrow.up.forward.square")
                    }
                    .help("Show this address in the block explorer")
                }
                if let address = model.address {
                    ShareLink(item: address) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 460, height: 600)
        .task { await model.load() }
    }

    private var networkPicker: some View {
        HStack(spacing: 6) {
            if let chain = model.chain {
                ChainIconView(name: chain.name, iconName: chain.iconName, accentHex: chain.accentHex, size: 20)
            }
            Picker("Network", selection: Binding(
                get: { model.chainID },
                set: { id in if let id { Task { await model.select(id) } } }
            )) {
                ForEach(model.chains) { chain in
                    Text(chain.isTestnet ? "\(chain.name) (testnet)" : chain.name).tag(ChainID?.some(chain.id))
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel("Network")
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            VStack(spacing: 12) {
                CometLoader(size: 56)
                Text("Loading your address…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 330)
        case .failed(let message):
            ErrorStateView("The address could not be loaded", message: message) {
                Task { await model.load() }
            }
            .frame(minHeight: 330)
        case .loaded(let address):
            QRCodeView(address)
                .frame(width: 236, height: 236)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                .padding(.top, 4)
            VStack(spacing: 8) {
                Text("Your \(model.chain?.name ?? "") address")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(AddressFormat.grouped(address))
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 380)
                    .accessibilityLabel(Text(AddressFormat.grouped(address)).speechSpellsOutCharacters())
                Button {
                    Clipboard.shared.copy(address)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy Address", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(minWidth: 130)
                }
                .brandProminentButton()
                .controlSize(.large)
            }
        }
    }
}
