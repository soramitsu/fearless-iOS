import DesignSystem
import SwiftUI
import WalletCore

/// The sidebar: wallet switcher, sections and the sync status.
struct SidebarView: View {
    @Bindable var app: AppModel

    private var sectionSelection: Binding<SidebarSection?> {
        Binding(get: { app.section }, set: { if let value = $0 { app.section = value } })
    }

    var body: some View {
        List(selection: sectionSelection) {
            Section("Wallet") {
                row(.portfolio)
                row(.assets)
                row(.activity, count: app.activity.pendingCount)
            }
            Section("Manage") {
                row(.networks, count: app.portfolio.failedChains.count)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            WalletSwitcher(app: app)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarStatus(app: app)
        }
    }

    /// A section row; the count (pending transfers, failing networks) shows as a badge.
    private func row(_ section: SidebarSection, count: Int = 0) -> some View {
        Label(section.title, systemImage: section.symbol)
            .badge(count)
            .tag(section)
    }
}

/// The wallet menu at the top of the sidebar.
struct WalletSwitcher: View {
    let app: AppModel

    var body: some View {
        Menu {
            ForEach(app.wallets) { wallet in
                Button {
                    Task { await app.selectWallet(wallet.id) }
                } label: {
                    Label {
                        Text(wallet.name + (app.needsBackup(wallet) ? "  ⚠︎" : ""))
                    } icon: {
                        Image(systemName: wallet.id == app.selectedWalletID ? "checkmark" : (wallet.isWatchOnly ? "eye" : "wallet.bifold"))
                    }
                }
            }
            Divider()
            Button("New Wallet…") { app.presentAddWallet(creating: true) }
            Button("Import Wallet…") { app.presentAddWallet(creating: false) }
            Divider()
            SettingsLink {
                Text("Manage Wallets…")
            }
        } label: {
            HStack(spacing: 9) {
                WalletAvatar(wallet: app.selectedWallet, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.selectedWallet?.name ?? "No Wallet")
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let wallet = app.selectedWallet, app.needsBackup(wallet) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(BrandColor.warning)
                        .font(.caption)
                        .help("This wallet is not backed up")
                        .accessibilityLabel("Not backed up")
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityLabel("Wallet")
        .accessibilityValue(app.selectedWallet?.name ?? "None")
        .help("Switch wallet (⌘1 to ⌘9) or add one")
    }

    private var subtitle: String {
        guard let wallet = app.selectedWallet else { return "Add a wallet to begin" }
        if wallet.isWatchOnly { return "Watch-only" }
        let count = app.wallets.count
        return count == 1 ? "1 wallet" : "\(count) wallets"
    }
}

/// A round mark for a wallet: its initial on a colour derived from its name.
struct WalletAvatar: View {
    let wallet: Wallet?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [color, color.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            if wallet?.isWatchOnly == true {
                Image(systemName: "eye.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var initial: String {
        String((wallet?.name.first(where: { $0.isLetter || $0.isNumber }) ?? "F")).uppercased()
    }

    private var color: Color {
        guard let wallet else { return BrandPalette.plum }
        let palette: [Color] = [BrandPalette.pinkActive, Color(hex: 0x6B3FD4), Color(hex: 0x0E8F8A), Color(hex: 0xC8651B), Color(hex: 0x3B64D8), Color(hex: 0x8E2C9A)]
        var hash: UInt32 = 2_166_136_261
        for byte in wallet.id.description.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return palette[Int(hash % UInt32(palette.count))]
    }
}

/// The sync dial with its words and the lock button, at the foot of the sidebar.
struct SidebarStatus: View {
    let app: AppModel

    var body: some View {
        let counts = app.portfolio.syncCounts
        let syncing = counts.total > 0 && counts.done + counts.failed < counts.total
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                SyncDial(done: counts.done, failed: counts.failed, total: counts.total, size: 18)
                Group {
                    if syncing {
                        Text("\(counts.done + counts.failed) / \(counts.total)")
                            .monospacedDigit()
                            .foregroundStyle(BrandColor.inFlight)
                    } else if counts.failed > 0 {
                        Text(counts.failed == 1 ? "1 network unavailable" : "\(counts.failed) networks unavailable")
                            .foregroundStyle(BrandColor.failure)
                    } else if counts.total > 0 {
                        Text("Up to date")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not synced")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    app.lock()
                } label: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Lock Fearless (⌃⌘L)")
                .accessibilityLabel("Lock Fearless")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .help(updatedText)
    }

    private var updatedText: String {
        guard let date = app.portfolio.lastUpdated else { return "Balances have not been loaded yet" }
        return "Updated \(date.formatted(date: .omitted, time: .shortened))"
    }
}
