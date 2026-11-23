import AppKit
import DesignSystem
import SwiftUI
import WalletCore
import WalletEngine
import WalletUI

// Renders the app's screens over the LIVE engine and checks address parity.
//
//   swift run LiveGallery <output folder> <path to docs/universal-wallet-v2-vectors.json>
//
// Uses a throwaway store in the temporary folder and its own keychain service,
// erased at the end. Imports the PUBLIC test phrase from the vectors file (it
// holds no funds of ours). Screens that would submit a transfer are never
// rendered. Windows are created far outside every display.

let password = "Live-Gallery-2026!"
/// Alice's generic-prefix (42) address: valid SS58, wrong network for Polkadot.
let genericPrefixAddress = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"

struct Vector: Decodable {
    struct Expected: Decodable {
        struct Substrate: Decodable { let polkadotAddress: String }
        struct EVM: Decodable { let address: String }
        let substrate: Substrate
        let evm: EVM
    }
    let id: String
    let mnemonic: String
    let expected: Expected
}

struct VectorFile: Decodable { let vectors: [Vector] }

@MainActor
final class LiveGallery {
    let output: URL
    let services: WalletServices
    let defaults: UserDefaults
    let suite = "fearless.livegallery.\(UUID().uuidString)"
    var written: [String] = []
    var failures: [String] = []
    var inputs = GalleryHost.Inputs(password: password, recipient: "", wrongNetworkRecipient: genericPrefixAddress, importWords: [])

    init(output: URL, services: WalletServices) {
        self.output = output
        self.services = services
        defaults = UserDefaults(suiteName: suite) ?? .standard
    }

    func host(_ screen: GalleryScreen, appearance: AppearancePreference) -> GalleryHost {
        let settings = AppSettings(defaults: defaults)
        settings.appearance = appearance
        NSApplication.shared.appearance = NSAppearance(named: appearance == .dark ? .darkAqua : .aqua)
        return GalleryHost(screen: screen, services: services, settings: settings, inputs: inputs)
    }

    func shoot(_ screen: GalleryScreen, _ appearance: AppearancePreference, size: CGSize = CGSize(width: 1440, height: 900)) async {
        let name = "live-\(screen.slug)-\(appearance == .dark ? "dark" : "light")"
        let gallery = host(screen, appearance: appearance)
        guard await gallery.prepare(timeout: .seconds(120)) else {
            failures.append("prepare \(name)")
            print("FAILED to prepare \(name)")
            return
        }
        // Give live balances and prices a moment to land in the view.
        try? await Task.sleep(for: .seconds(2))
        let image: CGImage?
        switch screen.presentation {
        case .mainWindow:
            image = await SnapshotRenderer.captureWindow(gallery.view, size: size, title: "Fearless Wallet", settleSeconds: 1.5)
        case .sheet:
            let backdropHost = host(.portfolio, appearance: appearance)
            _ = await backdropHost.prepare(timeout: .seconds(120))
            let backdrop = await SnapshotRenderer.captureWindow(backdropHost.view, size: size, title: "Fearless Wallet", settleSeconds: 1.0)
            let sheet = await SnapshotRenderer.capturePanel(gallery.view, settleSeconds: 1.0)
            if let backdrop, let sheet {
                image = SnapshotRenderer.composite(sheet: sheet, over: backdrop, scale: CGFloat(backdrop.width) / size.width)
            } else {
                image = nil
            }
        case .settings:
            let fitting = NSHostingView(rootView: AnyView(gallery.view.fixedSize(horizontal: true, vertical: true))).fittingSize
            image = await SnapshotRenderer.captureWindow(
                gallery.view,
                size: CGSize(width: max(640, fitting.width), height: fitting.height + 28),
                title: screen.slug,
                settleSeconds: 1.0
            )
        case .panel:
            image = await SnapshotRenderer.capturePanel(gallery.view, settleSeconds: 1.0)
        }
        guard let image else {
            failures.append("capture \(name)")
            print("FAILED to capture \(name)")
            return
        }
        do {
            try SnapshotRenderer.write(image, to: output.appendingPathComponent(name + ".png"))
            written.append(name)
            print("wrote \(name).png")
        } catch {
            failures.append("write \(name)")
        }
    }

    /// Derives every vector's addresses through the live engine.
    func checkParity(_ vectors: [Vector]) async -> [[String: String]] {
        var rows: [[String: String]] = []
        for vector in vectors {
            let words = vector.mnemonic.split(separator: " ").map(String.init)
            do {
                let preview = try await services.wallets.previewAddresses(for: .mnemonic(words: words, options: .standard))
                let substrateOK = preview.substrate == vector.expected.substrate.polkadotAddress
                let evmOK = preview.evm == vector.expected.evm.address
                rows.append([
                    "id": vector.id,
                    "substrate": substrateOK ? "match" : "MISMATCH \(preview.substrate ?? "nil")",
                    "evm": evmOK ? "match" : "MISMATCH \(preview.evm ?? "nil")"
                ])
                if !(substrateOK && evmOK) { failures.append("parity \(vector.id)") }
                print("parity \(vector.id): substrate \(substrateOK ? "match" : "MISMATCH"), evm \(evmOK ? "match" : "MISMATCH")")
            } catch {
                failures.append("parity \(vector.id): \(error.localizedDescription)")
            }
        }
        return rows
    }

    func run(vectors: [Vector]) async {
        await shoot(.onboardingWelcome, .dark)

        do {
            try await services.vault.initialize(password: password)
        } catch {
            failures.append("initialize: \(error.localizedDescription)")
            return
        }
        let parity = await checkParity(vectors)
        if let data = try? JSONSerialization.data(withJSONObject: parity, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: output.appendingPathComponent("address-parity.json"))
        }
        guard let first = vectors.first else { return }
        inputs.recipient = vectors.dropFirst().first?.expected.substrate.polkadotAddress ?? first.expected.substrate.polkadotAddress
        do {
            let words = first.mnemonic.split(separator: " ").map(String.init)
            _ = try await services.wallets.addWallet(name: "Public test vector", source: .mnemonic(words: words, options: .standard))
        } catch {
            failures.append("addWallet: \(error.localizedDescription)")
            return
        }

        // Never .sendProgress / .sendFinalized / .sendFailed: those submit.
        let screens: [GalleryScreen] = [
            .portfolio, .assets, .activity, .networks, .receive,
            .sendForm, .sendFormIssue, .settingsWallets, .settingsNetworks, .settingsSecurity, .menuBarExtra
        ]
        for screen in screens {
            await shoot(screen, .dark)
        }
        await shoot(.portfolio, .light)
        await shoot(.assets, .light)

        await services.vault.lock()
        await shoot(.lock, .dark)
    }
}

@MainActor
func main() async {
    let arguments = CommandLine.arguments
    guard arguments.count >= 3 else {
        print("usage: LiveGallery <output folder> <universal-wallet-v2-vectors.json>")
        exit(2)
    }
    let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
    try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: arguments[2])),
          let vectors = try? JSONDecoder().decode(VectorFile.self, from: data).vectors else {
        print("cannot read vectors")
        exit(2)
    }
    BrandFont.registerIfNeeded()

    let storage = FileManager.default.temporaryDirectory
        .appendingPathComponent("fearless-live-gallery-\(UUID().uuidString)", isDirectory: true)
    var configuration = WalletEngineConfiguration.default
    configuration.storageDirectory = storage
    configuration.keychainService += ".livegallery.\(UUID().uuidString.prefix(8))"
    let services = WalletEngineFactory.makeLiveServices(configuration: configuration)

    let gallery = LiveGallery(output: output, services: services)
    await gallery.run(vectors: vectors)

    try? await services.vault.eraseAllData()
    try? FileManager.default.removeItem(at: storage)
    UserDefaults.standard.removePersistentDomain(forName: gallery.suite)

    print("Rendered \(gallery.written.count) screens; failures: \(gallery.failures.isEmpty ? "none" : gallery.failures.joined(separator: "; "))")
    exit(gallery.failures.isEmpty ? 0 : 1)
}

ToolAccent.applyIfUnset()
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
Task { @MainActor in
    await main()
}
application.run()
