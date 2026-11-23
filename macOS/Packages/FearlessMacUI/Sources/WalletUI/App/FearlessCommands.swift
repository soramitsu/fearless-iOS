import AppKit
import SwiftUI
import WalletCore

/// The menu bar. Every action of the toolbar and the context menus is here
/// too, with a keyboard shortcut.
///
/// Each menu's items live in their own small `View` type below, so this
/// body stays a flat list of menus and each menu can be read on its own.
struct FearlessCommands: Commands {
    let app: AppModel

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            AboutMenuItem()
        }
        CommandGroup(replacing: .newItem) {
            NewWalletMenuItems(app: app)
        }
        CommandGroup(after: .textEditing) {
            SearchMenuItem(app: app)
        }
        SidebarCommands()
        InspectorCommands()
        CommandGroup(after: .sidebar) {
            ViewMenuItems(app: app)
        }
        CommandMenu("Wallet") {
            WalletMenuItems(app: app)
        }
        CommandGroup(replacing: .help) {
            HelpMenuItems()
        }
    }
}

// MARK: - App menu

struct AboutMenuItem: View {
    var body: some View {
        Button("About Fearless Wallet") {
            AboutPanel.show()
        }
    }
}

// MARK: - File menu

struct NewWalletMenuItems: View {
    let app: AppModel

    var body: some View {
        Button("New Wallet…") { app.presentAddWallet(creating: true) }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(app.route != .main)
        Button("Import Wallet…") { app.presentAddWallet(creating: false) }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(app.route != .main)
    }
}

// MARK: - Edit menu

struct SearchMenuItem: View {
    let app: AppModel

    var body: some View {
        Button("Search") { SearchFieldFocus.focus() }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(app.route != .main)
    }
}

// MARK: - View menu

struct ViewMenuItems: View {
    let app: AppModel

    var body: some View {
        Divider()
        SectionMenuItem(app: app, section: .portfolio, key: "1")
        SectionMenuItem(app: app, section: .assets, key: "2")
        SectionMenuItem(app: app, section: .activity, key: "3")
        SectionMenuItem(app: app, section: .networks, key: "4")
        Divider()
        Toggle("Hide Balances", isOn: hideBalances)
            .keyboardShortcut("h", modifiers: [.command, .shift])
        Toggle("Show Testnets", isOn: showTestnets)
        Toggle("Hide Zero Balances", isOn: hideZeroBalances)
    }

    private var hideBalances: Binding<Bool> {
        Binding(get: { app.settings.balancesHidden }, set: { app.settings.balancesHidden = $0 })
    }

    private var showTestnets: Binding<Bool> {
        Binding(get: { app.settings.showTestnets }, set: { app.settings.showTestnets = $0 })
    }

    private var hideZeroBalances: Binding<Bool> {
        Binding(get: { app.settings.hideZeroBalances }, set: { app.settings.hideZeroBalances = $0 })
    }
}

/// "Portfolio ⌥⌘1" and its siblings.
struct SectionMenuItem: View {
    let app: AppModel
    let section: SidebarSection
    let key: Character

    var body: some View {
        Button(section.title) { app.section = section }
            .keyboardShortcut(KeyEquivalent(key), modifiers: [.command, .option])
            .disabled(app.route != .main)
    }
}

// MARK: - Wallet menu

struct WalletMenuItems: View {
    let app: AppModel

    private var hasWallet: Bool { app.route == .main && app.selectedWallet != nil }
    private var canSend: Bool { hasWallet && app.selectedWallet?.isWatchOnly == false }

    var body: some View {
        Button("Send…") { app.presentSend() }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!canSend)
        Button("Receive…") { app.presentReceive() }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!hasWallet)
        Divider()
        Button("Refresh") { Task { await app.refresh() } }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(!hasWallet)
        Button("Copy Address") { Task { await app.copyAddress() } }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!hasWallet)
        Divider()
        WalletSwitchMenuItems(app: app)
        Button("Lock Fearless") { app.lock() }
            .keyboardShortcut("l", modifiers: [.command, .control])
            .disabled(!app.isUnlocked)
    }
}

/// One item per wallet (⌘1 … ⌘9), followed by a divider when there are any.
struct WalletSwitchMenuItems: View {
    let app: AppModel

    private struct Entry: Identifiable {
        let id: WalletID
        let name: String
        let key: Character?
        let isSelected: Bool
    }

    private var entries: [Entry] {
        let keys = Array("123456789")
        return app.wallets.enumerated().map { index, wallet in
            Entry(
                id: wallet.id,
                name: wallet.name,
                key: index < keys.count ? keys[index] : nil,
                isSelected: wallet.id == app.selectedWalletID
            )
        }
    }

    var body: some View {
        ForEach(entries) { entry in
            WalletSwitchMenuItem(app: app, walletID: entry.id, name: entry.name, key: entry.key, isSelected: entry.isSelected)
        }
        WalletSwitchDivider(isVisible: !app.wallets.isEmpty)
    }
}

struct WalletSwitchMenuItem: View {
    let app: AppModel
    let walletID: WalletID
    let name: String
    let key: Character?
    let isSelected: Bool

    var body: some View {
        if let key {
            WalletSwitchToggle(app: app, walletID: walletID, name: name, isSelected: isSelected)
                .keyboardShortcut(KeyEquivalent(key), modifiers: .command)
        } else {
            WalletSwitchToggle(app: app, walletID: walletID, name: name, isSelected: isSelected)
        }
    }
}

/// A checkable menu item: the selected wallet carries the check mark.
struct WalletSwitchToggle: View {
    let app: AppModel
    let walletID: WalletID
    let name: String
    let isSelected: Bool

    var body: some View {
        Toggle(name, isOn: Binding(
            get: { isSelected },
            set: { _ in Task { await app.selectWallet(walletID) } }
        ))
    }
}

struct WalletSwitchDivider: View {
    let isVisible: Bool

    var body: some View {
        if isVisible {
            Divider()
        }
    }
}

// MARK: - Help menu

struct HelpMenuItems: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Acknowledgements") {
            openWindow(id: FearlessScenes.acknowledgementsWindowID)
        }
    }
}

/// The standard About panel with the app's version and font credits.
@MainActor
enum AboutPanel {
    static func show() {
        let credits = NSMutableAttributedString(
            string: "A non-custodial wallet for the Polkadot ecosystem and Ethereum.\nYour keys stay on this Mac.\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        credits.append(NSAttributedString(
            string: "Figtree typeface © 2022 The Figtree Project Authors, SIL Open Font License 1.1. See Help ▸ Acknowledgements.",
            attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.secondaryLabelColor]
        ))
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Fearless Wallet",
            .credits: credits
        ])
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

/// Puts the insertion point in the toolbar's search field (⌘F).
@MainActor
enum SearchFieldFocus {
    static func focus() {
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow else { return }
        for item in window.toolbar?.items ?? [] {
            if let search = item as? NSSearchToolbarItem {
                window.makeFirstResponder(search.searchField)
                return
            }
        }
    }
}
