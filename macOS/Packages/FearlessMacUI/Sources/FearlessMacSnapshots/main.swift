import AppKit
import DesignSystem
import SwiftUI
import WalletCore
import WalletPreviewSupport
import WalletUI

// Renders every gallery screen to PNG files with the in-memory preview
// services, in light and dark appearance.
//
//   swift run FearlessMacSnapshots <output folder> [--only a,b] [--sizes 1280x820,1680x1050] [--appearance light|dark]
//       [-AppleLanguages "(en)" -AppleLocale en_US]
//
// The executable has no bundle, so dates and numbers follow the system
// language; pass the two -Apple arguments to render them as the English app does.
//
// Windows are created far outside every display, so nothing appears on screen.

struct Options {
    var output: URL
    var only: Set<String>?
    var sizes: [CGSize] = [CGSize(width: 1280, height: 820), CGSize(width: 1680, height: 1050)]
    var appearances: [AppearancePreference] = [.light, .dark]

    init(arguments: [String]) {
        var output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("snapshots")
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            let next = arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
            switch argument {
            case "--only":
                if let next { only = Set(next.split(separator: ",").map(String.init)) }
                index += 1
            case "--sizes":
                if let next {
                    sizes = next.split(separator: ",").compactMap { pair in
                        let parts = pair.split(separator: "x").compactMap { Double($0) }
                        return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
                    }
                }
                index += 1
            case "--appearance":
                if let next, let preference = AppearancePreference(rawValue: next) { appearances = [preference] }
                index += 1
            default:
                if argument.hasPrefix("-Apple") {
                    // -AppleLanguages / -AppleLocale and their value belong to Foundation.
                    index += 1
                } else {
                    output = URL(fileURLWithPath: argument)
                }
            }
            index += 1
        }
        self.output = output
    }
}

@MainActor
func render(_ job: SnapshotJob, appearance: AppearancePreference, options: Options) async -> [String] {
    var written: [String] = []
    let suite = "fearless.snapshots.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else { return [] }
    defer { defaults.removePersistentDomain(forName: suite) }

    func makeHost(_ screen: GalleryScreen, scenario: PreviewScenario) -> GalleryHost {
        let settings = AppSettings(defaults: defaults)
        settings.appearance = appearance
        settings.balancesHidden = job.balancesHidden
        settings.showTestnets = job.showTestnets
        return GalleryHost(screen: screen, services: PreviewWalletServices.make(scenario: scenario), settings: settings, inputs: SnapshotJob.inputs)
    }

    NSApplication.shared.appearance = appearance == .dark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
    let tag = appearance == .dark ? "dark" : "light"

    func save(_ image: CGImage?, _ name: String) {
        guard let image else {
            print("FAILED to capture \(name)")
            return
        }
        let url = options.output.appendingPathComponent(name + ".png")
        do {
            try SnapshotRenderer.write(image, to: url)
            written.append(url.lastPathComponent)
        } catch {
            print("FAILED to write \(name): \(error.localizedDescription)")
        }
    }

    switch job.screen.presentation {
    case .mainWindow:
        for size in options.sizes {
            let host = makeHost(job.screen, scenario: job.scenario)
            guard await host.prepare() else {
                print("FAILED to prepare \(job.name)")
                continue
            }
            let image = await SnapshotRenderer.captureWindow(host.view, size: size, title: "Fearless Wallet", settleSeconds: 1.2)
            save(image, "\(job.name)-\(tag)-\(Int(size.width))x\(Int(size.height))")
        }
    case .sheet:
        guard let size = options.sizes.first else { break }
        let backdropHost = makeHost(.portfolio, scenario: PreviewScenario.standard.instant())
        let host = makeHost(job.screen, scenario: job.scenario)
        guard await backdropHost.prepare(), await host.prepare() else {
            print("FAILED to prepare \(job.name)")
            break
        }
        let backdrop = await SnapshotRenderer.captureWindow(backdropHost.view, size: size, title: "Fearless Wallet", settleSeconds: 1.0)
        let sheet = await SnapshotRenderer.capturePanel(host.view, settleSeconds: 1.0)
        if let backdrop, let sheet {
            let scale = CGFloat(backdrop.width) / size.width
            save(SnapshotRenderer.composite(sheet: sheet, over: backdrop, scale: scale), "\(job.name)-\(tag)")
        } else {
            print("FAILED to capture \(job.name)")
        }
    case .settings:
        let host = makeHost(job.screen, scenario: job.scenario)
        guard await host.prepare() else {
            print("FAILED to prepare \(job.name)")
            break
        }
        let view = AnyView(host.view.fixedSize(horizontal: true, vertical: true))
        let probe = NSHostingView(rootView: view)
        let fitting = probe.fittingSize
        let title = job.screen.rawValue.replacingOccurrences(of: "settings", with: "")
        let image = await SnapshotRenderer.captureWindow(
            host.view,
            size: CGSize(width: max(640, fitting.width), height: fitting.height + 28),
            title: title,
            settleSeconds: 1.0
        )
        save(image, "\(job.name)-\(tag)")
    case .panel:
        let host = makeHost(job.screen, scenario: job.scenario)
        guard await host.prepare() else {
            print("FAILED to prepare \(job.name)")
            break
        }
        save(await SnapshotRenderer.capturePanel(host.view, settleSeconds: 1.0), "\(job.name)-\(tag)")
    }
    return written
}

@MainActor
func runSnapshots() async {
    let options = Options(arguments: CommandLine.arguments)
    try? FileManager.default.createDirectory(at: options.output, withIntermediateDirectories: true)
    BrandFont.registerIfNeeded()
    let jobs = SnapshotJob.all.filter { options.only?.contains($0.name) ?? true }
    var total = 0
    for job in jobs {
        for appearance in options.appearances {
            let files = await render(job, appearance: appearance, options: options)
            total += files.count
            for file in files { print("wrote \(file)") }
        }
    }
    print("Rendered \(total) images to \(options.output.path)")
    exit(0)
}

ToolAccent.applyIfUnset()
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
Task { @MainActor in
    await runSnapshots()
}
application.run()
