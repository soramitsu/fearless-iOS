import AppKit
import DesignSystem
import SwiftUI
import WalletCore

/// The crest in the menu bar.
struct MenuBarLabel: View {
    var body: some View {
        if let image = NSImage.fearlessMenuBarCrest() {
            Image(nsImage: image)
                .accessibilityLabel("Fearless Wallet")
        } else {
            Image(systemName: "bird")
                .accessibilityLabel("Fearless Wallet")
        }
    }
}

/// The menu bar extra's panel: total balance, quick address copy, Receive,
/// opening the main window and Lock. Amounts follow privacy mode and never
/// show while the app is locked.
struct MenuBarPanel: View {
    let app: AppModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CrestBadge(size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(app.isUnlocked ? (app.selectedWallet?.name ?? "Fearless Wallet") : "Fearless Wallet")
                        .font(.headline)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if app.isUnlocked {
                    Button {
                        app.toggleBalancesHidden()
                    } label: {
                        Image(systemName: app.settings.balancesHidden ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(app.settings.balancesHidden ? "Show balances" : "Hide balances")
                    .accessibilityLabel(app.settings.balancesHidden ? "Show balances" : "Hide balances")
                }
            }

            if app.isUnlocked, app.selectedWallet != nil {
                unlockedContent
            } else {
                Text(app.route == .locked ? "Unlock Fearless to see your balance and addresses." : "Finish setting up Fearless in its window.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            HStack(spacing: 8) {
                Button(app.isUnlocked ? "Open Fearless" : "Open to Unlock") { showMainWindow() }
                    .brandProminentButton()
                if app.isUnlocked {
                    Button {
                        app.lock()
                    } label: {
                        Label("Lock", systemImage: "lock.fill")
                    }
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 312)
        .tint(BrandColor.accent)
        .environment(\.balancesHidden, app.settings.balancesHidden)
    }

    private var statusText: String {
        switch app.route {
        case .locked: return "Locked"
        case .launching: return "Starting…"
        case .onboarding: return "Setup"
        case .main: return app.selectedWallet?.isWatchOnly == true ? "Watch-only" : "Unlocked"
        }
    }

    @ViewBuilder private var unlockedContent: some View {
        let summary = app.summary
        VStack(alignment: .leading, spacing: 2) {
            Text("Total balance")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(app.totalValueText)
                .font(.system(size: 26, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel("Total balance")
                .accessibilityValue(app.settings.balancesHidden ? "Hidden" : app.totalValueText)
            if summary.pricedRowCount > 0 {
                HStack(spacing: 4) {
                    ChangeText(percent: summary.changePercent)
                    Text("24h").foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }

        if let wallet = app.selectedWallet {
            let chains = quickChains(for: wallet)
            if !chains.isEmpty {
                VStack(spacing: 6) {
                    ForEach(chains) { chain in
                        Button {
                            Task { await app.copyAddress(on: chain) }
                        } label: {
                            HStack(spacing: 8) {
                                ChainIconView(name: chain.name, iconName: chain.iconName, accentHex: chain.accentHex, size: 18)
                                Text("Copy \(chain.name) Address")
                                Spacer()
                                Image(systemName: "doc.on.doc").foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    Button {
                        showMainWindow()
                        app.presentReceive()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode").frame(width: 18)
                            Text("Receive…")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .font(.callout)
            }
        }
    }

    /// The first main network of each ecosystem the wallet has.
    private func quickChains(for wallet: Wallet) -> [Chain] {
        let chains = app.portfolio.chains(for: wallet, includeTestnets: false)
        var result: [Chain] = []
        for ecosystem in Ecosystem.allCases {
            if let chain = chains.first(where: { $0.ecosystem == ecosystem }) { result.append(chain) }
        }
        return result
    }

    private func showMainWindow() {
        openWindow(id: FearlessScenes.mainWindowID)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
