import AppKit
import DesignSystem
import SwiftUI
import WalletCore
import WalletPreviewSupport
import WalletUI

/// Runs the whole interface over in-memory sample data, without the wallet
/// engine: `swift run FearlessMacDemo [--scenario <name>] [--slow]`.
///
/// Scenarios: `standard` (default: unlocked, three wallets), `first-run`,
/// `locked`, `empty`, `balance-failure`, `transfer-fails`. The sample app
/// password is printed at launch. Nothing here is real: the accounts are
/// public development accounts and the recovery phrases are published test
/// vectors.
@main
enum DemoMain {
    static func main() {
        if CommandLine.arguments.contains("--menu-bar-test") {
            MenuBarTestApp.main()
        } else {
            FearlessMacDemoApp.main()
        }
    }
}

struct FearlessMacDemoApp: App {
    @NSApplicationDelegateAdaptor(DemoAppDelegate.self) private var delegate

    private let services: WalletServices

    init() {
        setvbuf(stdout, nil, _IOLBF, 0)
        if CommandLine.arguments.contains("--main-thread-stacks") {
            MainThreadStacks.printPeriodically()
        }
        ToolAccent.applyIfUnset()
        let scenario = DemoArguments.scenario()
        services = PreviewWalletServices.make(scenario: scenario)
        print("Fearless Wallet demo. Sample data only. App password: \(PreviewWalletServices.samplePassword)")
        if CommandLine.arguments.contains("--exercise-settings") {
            SettingsExerciser.schedule()
        }
    }

    var body: some Scene {
        // Exactly what the app target does.
        FearlessScenes(services: services)
    }
}

/// For automated checks: a few seconds after launch, chooses View menu
/// items the way a user would (each one changes a preference) and prints a
/// heartbeat from the main actor, to prove the interface keeps running
/// when settings change.
@MainActor
enum SettingsExerciser {
    static func schedule() {
        Task { @MainActor in
            let start = Date()
            func stamp() -> String { String(format: "t=%.1fs", Date().timeIntervalSince(start)) }
            try? await Task.sleep(for: .seconds(5))
            for title in ["Hide Balances", "Show Testnets", "Hide Zero Balances", "Hide Balances", "Show Testnets", "Hide Zero Balances"] {
                let clicked = MenuDump.choose(menu: "View", item: title)
                print("SETTINGS: \(stamp()) chose View > \(title): \(clicked ? "ok" : "NOT FOUND")")
                try? await Task.sleep(for: .seconds(1.2))
            }
            for _ in 0..<4 {
                print("ALIVE: \(stamp())")
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }
}

enum DemoArguments {
    static func scenario(arguments: [String] = CommandLine.arguments) -> PreviewScenario {
        var scenario: PreviewScenario
        let name = value(after: "--scenario", in: arguments) ?? "standard"
        switch name {
        case "first-run": scenario = .firstRun
        case "locked": scenario = .locked
        case "empty": scenario = .emptyWalletList
        case "balance-failure": scenario = .balanceFailure
        case "transfer-fails": scenario = .transferFailsAtInclusion
        default: scenario = .standard
        }
        if arguments.contains("--slow") { scenario.latency = .slow }
        if arguments.contains("--touch-id") { scenario.biometrics = .enabled }
        return scenario
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

/// Makes the bundle-less executable a regular foreground app with a Dock
/// icon and a menu bar.
///
/// Flags for automated checks: `--no-activate` leaves the frontmost app
/// alone, `--dump-menus` builds every menu a few seconds after launch and
/// prints its items with their shortcuts, `--exercise-settings` chooses
/// View menu items that change preferences and prints a heartbeat, and
/// `--main-thread-stacks` prints what the main thread is doing a few times
/// (to find a hang).
final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        if let icon = BrandIcon.applicationIcon() {
            NSApplication.shared.applicationIconImage = icon
        }
        if !CommandLine.arguments.contains("--no-activate") {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        if CommandLine.arguments.contains("--dump-menus") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                MenuDump.printMainMenu()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

/// Walks the main menu the way opening each menu would, so every command's
/// content is built, and prints what it finds.
@MainActor
enum MenuDump {
    static func printMainMenu() {
        guard let mainMenu = NSApplication.shared.mainMenu else {
            print("MENU: no main menu")
            return
        }
        for item in mainMenu.items {
            guard let submenu = item.submenu else { continue }
            dump(submenu, title: item.title.isEmpty ? submenu.title : item.title, depth: 0)
        }
        print("MENU: done")
        fflush(stdout)
    }

    /// Chooses a menu item by title, as a click would. False when it is missing or disabled.
    static func choose(menu menuTitle: String, item itemTitle: String) -> Bool {
        guard let mainMenu = NSApplication.shared.mainMenu,
              let menu = mainMenu.items.first(where: { $0.title == menuTitle || $0.submenu?.title == menuTitle })?.submenu
        else { return false }
        menu.delegate?.menuNeedsUpdate?(menu)
        menu.update()
        guard let index = menu.items.firstIndex(where: { $0.title == itemTitle }), menu.items[index].isEnabled else { return false }
        menu.performActionForItem(at: index)
        return true
    }

    private static func dump(_ menu: NSMenu, title: String, depth: Int) {
        menu.delegate?.menuNeedsUpdate?(menu)
        menu.update()
        let indent = String(repeating: "  ", count: depth)
        print("MENU: \(indent)[\(title)]")
        for item in menu.items {
            if item.isSeparatorItem {
                print("MENU: \(indent)  ---")
                continue
            }
            var shortcut = ""
            if !item.keyEquivalent.isEmpty {
                let flags = item.keyEquivalentModifierMask
                if flags.contains(.control) { shortcut += "⌃" }
                if flags.contains(.option) { shortcut += "⌥" }
                if flags.contains(.shift) { shortcut += "⇧" }
                if flags.contains(.command) { shortcut += "⌘" }
                shortcut += item.keyEquivalent.uppercased()
            }
            let state = item.isEnabled ? "" : " (disabled)"
            let check = item.state == .on ? " ✓" : ""
            print("MENU: \(indent)  \(item.title)\(check)\(shortcut.isEmpty ? "" : "  " + shortcut)\(state)")
            if let submenu = item.submenu, depth < 2 {
                dump(submenu, title: item.title, depth: depth + 1)
            }
        }
    }
}

/// Prints the main thread's call stack a few times, from a signal handler,
/// so a busy main thread can be diagnosed without attaching a debugger.
enum MainThreadStacks {
    static func printPeriodically() {
        // A thread handle is only passed to pthread_kill below.
        nonisolated(unsafe) let main = pthread_self()
        signal(SIGUSR1) { _ in
            var frames = [UnsafeMutableRawPointer?](repeating: nil, count: 96)
            let count = backtrace(&frames, 96)
            backtrace_symbols_fd(&frames, count, 2)
            write(2, "----\n", 5)
        }
        let thread = Thread {
            for delay in [6.0, 1.5, 1.5] {
                Thread.sleep(forTimeInterval: delay)
                pthread_kill(main, SIGUSR1)
            }
        }
        thread.start()
    }
}

/// A second entry point for one automated check: it owns the app model, so
/// it can turn the menu bar extra on and off (the one preference the scene
/// list itself depends on) and print a heartbeat to prove nothing loops.
struct MenuBarTestApp: App {
    @NSApplicationDelegateAdaptor(DemoAppDelegate.self) private var delegate

    private let model: AppModel

    init() {
        setvbuf(stdout, nil, _IOLBF, 0)
        ToolAccent.applyIfUnset()
        let model = AppModel(services: PreviewWalletServices.make(scenario: DemoArguments.scenario()))
        self.model = model
        print("Fearless Wallet demo, menu bar test.")
        Task { @MainActor in
            let start = Date()
            func stamp() -> String { String(format: "t=%.1fs", Date().timeIntervalSince(start)) }
            let original = model.settings.menuBarExtraEnabled
            for value in [true, false, true, original] {
                try? await Task.sleep(for: .seconds(2.5))
                model.settings.menuBarExtraEnabled = value
                print("MENUBAR: \(stamp()) menu bar extra = \(value)")
            }
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(1.5))
                print("ALIVE: \(stamp())")
            }
        }
    }

    var body: some Scene {
        FearlessScenes(model: model)
    }
}
