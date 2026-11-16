@testable import fearless
import AVFoundation
import UIKit
import XCTest

/// The launch overlay, the debug seams' notifications and the rolling label's count-up and crossfade.
@MainActor
final class CovEDesignSystemTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames {
            UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        }
        suiteNames = []
        super.tearDown()
    }

    func testLaunchOverlayLaysOutTheClipAndForwardsTaps() throws {
        let overlay = FWLaunchOverlayViewController()
        var taps = 0
        overlay.onTap = { taps += 1 }
        let window = CovEHost.window(for: overlay)
        defer { CovEHost.close(window) }
        XCTAssertEqual(overlay.preferredStatusBarStyle, .lightContent)
        XCTAssertEqual(overlay.supportedInterfaceOrientations, .all)
        XCTAssertTrue(overlay.view.accessibilityElementsHidden)
        overlay.view.layoutIfNeeded()
        XCTAssertEqual(
            overlay.playerLayer.frame,
            FWLaunchTimeline.videoFrame(in: overlay.view.bounds, focus: FWLaunchTimeline.kitV3.focus.phone)
        )
        let player = AVPlayer()
        overlay.attach(player: player, focus: FWLaunchTimeline.Point(x: 0.5, y: 0.5))
        overlay.view.layoutIfNeeded()
        XCTAssertTrue(overlay.playerLayer.player === player)
        XCTAssertEqual(
            overlay.playerLayer.frame,
            FWLaunchTimeline.videoFrame(in: overlay.view.bounds, focus: FWLaunchTimeline.Point(x: 0.5, y: 0.5))
        )
        overlay.detach()
        XCTAssertNil(overlay.playerLayer.player)
        let crest = try XCTUnwrap(CovEFind.first(UIImageView.self, in: overlay.view))
        overlay.fadeCrest(duration: 0)
        XCTAssertEqual(crest.alpha, 0)
        let tap = try XCTUnwrap(overlay.view.gestureRecognizers?.first)
        overlay.perform(NSSelectorFromString("tapped"), with: tap)
        XCTAssertEqual(taps, 1)

        let landingWindow = CovEHost.makeWindow()
        landingWindow.isHidden = false
        defer { CovEHost.close(landingWindow) }
        let next = UIViewController()
        FWLandingAnimationCoordinator(effects: makeEffects(.automatic), tokens: nil).animateTransition(to: next, in: landingWindow)
        XCTAssertTrue(landingWindow.rootViewController === next)
        XCTAssertTrue(next.isViewLoaded || landingWindow.subviews.contains(next.view), "The new root is installed without the flight")
    }

    func testDebugSeamsPostSyncAndTickNotifications() {
        XCTAssertEqual(FWShikibanDebugSeams.prefix, "jp.co.soramitsu.fearless.debug.")
        XCTAssertTrue(FWShikibanDebugSeams.names.contains("dialfail"))
        var failures: [Int] = []
        var ticks = 0
        let syncObserver = NotificationCenter.default.addObserver(
            forName: FWShikibanDebugSeams.syncNotification, object: nil, queue: nil
        ) { failures.append($0.userInfo?["failures"] as? Int ?? -1) }
        let tickObserver = NotificationCenter.default.addObserver(
            forName: FWShikibanDebugSeams.tickNotification, object: nil, queue: nil
        ) { _ in ticks += 1 }
        defer {
            NotificationCenter.default.removeObserver(syncObserver)
            NotificationCenter.default.removeObserver(tickObserver)
        }
        FWShikibanDebugSeams.handle("dial")
        FWShikibanDebugSeams.handle("dialfail")
        FWShikibanDebugSeams.handle("tick")
        FWShikibanDebugSeams.handle("unknown-seam")
        XCTAssertEqual(failures, [0, 2])
        XCTAssertEqual(ticks, 1)

        FWShikibanDebugSeams.install()
        FWShikibanDebugSeams.install()
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName((FWShikibanDebugSeams.prefix + "tick") as CFString), nil, nil, true
        )
        XCTAssertTrue(CovEHost.spin(until: { ticks == 2 }, timeout: 2), "Installed seams answer Darwin notifications")
    }

    func testRollingLabelCountsUpAndCrossfadesUnderReducedEffects() {
        let full = FWRollingLabel(effects: makeEffects(.automatic))
        full.font = .systemFont(ofSize: 20)
        full.textAlignment = .center
        full.countUp(to: "$1,234.50")
        XCTAssertEqual(full.text, "$1,234.50", "Off screen the value is shown at once")
        let window = CovEHost.window(for: full, frame: CGRect(x: 16, y: 100, width: 300, height: 30))
        defer { CovEHost.close(window) }
        XCTAssertTrue(full.isCounting, "A pending count starts once the label is on screen")
        XCTAssertEqual(full.accessibilityLabel, "$1,234.50", "VoiceOver reads the final value while counting")
        full.setText("$2,000.00", animated: true)
        XCTAssertTrue(full.isCounting, "A new value while counting carries the count on")
        XCTAssertTrue(CovEHost.spin(until: { !full.isCounting }, timeout: 3))
        XCTAssertEqual(full.text, "$2,000.00")
        XCTAssertNil(full.accessibilityLabel)
        full.countUp(to: "not a number")
        XCTAssertEqual(full.text, "not a number")
        XCTAssertFalse(full.isCounting)

        let reduced = FWRollingLabel(effects: makeEffects(.reduced))
        reduced.settledColor = .white
        let second = CovEHost.window(for: reduced, frame: CGRect(x: 16, y: 200, width: 300, height: 30))
        defer { CovEHost.close(second) }
        reduced.setText("$10.00", animated: false)
        reduced.setText("$12.00", animated: true)
        XCTAssertTrue(reduced.isAnimatingChange, "Reduced effects crossfade the change")
        XCTAssertNotNil(reduced.attributedText)
        XCTAssertTrue(CovEHost.spin(until: { !reduced.isAnimatingChange }, timeout: 3))
        XCTAssertEqual(reduced.text, "$12.00")
        reduced.countUp(to: "$20.00")
        XCTAssertEqual(reduced.text, "$20.00", "Reduced effects never count")
        reduced.setText("$13.00", animated: true)
        reduced.removeFromSuperview()
        XCTAssertFalse(reduced.isAnimatingChange, "Leaving the window settles the label")
        XCTAssertEqual(reduced.textColor, .white)
    }

    func testValueTickSlidesDrawsTheLineAndRespectsTheQuietPeriod() throws {
        let effects = makeEffects(.automatic)
        let label = UILabel()
        label.text = "$12.00"
        label.textAlignment = .center
        XCTAssertFalse(FWValueTick.tick(label, direction: .rising, key: "covE-offscreen", effects: effects), "Off-screen labels never tick")
        let window = CovEHost.window(for: label, frame: CGRect(x: 16, y: 100, width: 200, height: 24))
        defer { CovEHost.close(window) }
        FWValueTick.resetForTesting()
        XCTAssertFalse(FWValueTick.tick(label, direction: .none, key: "covE-tick", effects: effects))
        XCTAssertTrue(FWValueTick.tick(label, direction: .rising, key: "covE-tick", effects: effects))
        XCTAssertNotNil(label.layer.animation(forKey: FWValueTick.slideKey))
        XCTAssertFalse(FWValueTick.tick(label, direction: .falling, key: "covE-tick", effects: effects), "A second tick inside the quiet period is dropped")
        XCTAssertTrue(CovEHost.spin(until: { label.layer.sublayers?.contains { $0.name == FWValueTick.lineName } == true }, timeout: 1))
        XCTAssertTrue(FWValueTick.claim(key: "covE-claim", now: 100))
        XCTAssertFalse(FWValueTick.claim(key: "covE-claim", now: 101))
        XCTAssertTrue(FWValueTick.claim(key: "covE-claim", now: 104))

        let line = try XCTUnwrap(FWValueTick.line(under: label, direction: .falling, effects: effects))
        XCTAssertEqual(line.backgroundColor, FWSunlit.Palette.priceDown.cgColor)
        XCTAssertEqual(label.layer.sublayers?.filter { $0.name == FWValueTick.lineName }.count, 1, "A new line replaces the old one")
        XCTAssertEqual(line.position.x, (200 - min(200, label.intrinsicContentSize.width)) / 2, accuracy: 0.5)
        label.textAlignment = .right
        XCTAssertEqual(
            FWValueTick.line(under: label, direction: .rising, effects: effects)?.position.x ?? -1,
            200 - min(200, label.intrinsicContentSize.width),
            accuracy: 0.5
        )
        label.textAlignment = .natural
        XCTAssertEqual(FWValueTick.line(under: label, direction: .rising, effects: effects)?.position.x, 0)
        XCTAssertNil(FWValueTick.line(under: label, direction: .none, effects: effects))
        let reduced = makeEffects(.reduced)
        XCTAssertFalse(FWValueTick.allowed(effects: reduced))
        XCTAssertNil(FWValueTick.line(under: label, direction: .rising, effects: reduced))
        FWValueTick.resetForTesting()
    }

    func testValueFlashTintsAndSettlesTheLabel() {
        let label = UILabel()
        label.text = "$1.00"
        FWValueFlash.flash(label, direction: .rising, settledColor: .white, effects: makeEffects(.automatic))
        XCTAssertNotEqual(label.textColor, FWSunlit.Palette.priceUp, "Off-screen labels are not tinted")
        let window = CovEHost.window(for: label, frame: CGRect(x: 16, y: 100, width: 200, height: 24))
        defer { CovEHost.close(window) }
        FWValueFlash.flash(label, direction: .none, settledColor: .white, effects: makeEffects(.automatic))
        FWValueFlash.flash(label, direction: .falling, settledColor: .white, effects: makeEffects(.automatic))
        XCTAssertEqual(label.textColor, FWSunlit.Palette.priceDown)
        XCTAssertTrue(CovEHost.spin(until: { label.textColor == .white }, timeout: 2), "The tint settles back")
        FWValueFlash.flash(label, direction: .rising, settledColor: .gray, effects: makeEffects(.reduced))
        XCTAssertEqual(label.textColor, FWSunlit.Palette.priceUp)
        label.text = "$2.00"
        XCTAssertTrue(CovEHost.spin(until: { label.textColor == .gray }, timeout: 2), "A changed value settles at once")
    }

    func testWelcomeBackgroundPaintsBlobsOnlyWithFullEffects() throws {
        let size = CGSize(width: 100, height: 200)
        func render(_ choice: FWEffectsChoice) -> UIImage {
            let view = FWWelcomeBackgroundView(effects: makeEffects(choice))
            view.frame = CGRect(origin: .zero, size: size)
            view.traitCollectionDidChange(nil)
            return UIGraphicsImageRenderer(size: size).image { _ in view.draw(view.bounds) }
        }
        let point = CGPoint(x: 15, y: 24)
        XCTAssertGreaterThan(try XCTUnwrap(CovEPixel.alpha(of: render(.automatic), at: point)), 0)
        XCTAssertEqual(try XCTUnwrap(CovEPixel.alpha(of: render(.reduced), at: point)), 0, "Reduced effects paint no blobs")
        let view = FWWelcomeBackgroundView(effects: makeEffects(.automatic))
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertEqual(view.backgroundColor, R.color.fwBgBase())
    }

    // MARK: - Helpers

    private func makeEffects(_ choice: FWEffectsChoice) -> FWEffects {
        let suiteName = "covE-effects-" + UUID().uuidString
        suiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
        effects.userChoice = choice
        return effects
    }
}

enum CovEPixel {
    /// Alpha of the pixel at a point (in points) of an image.
    static func alpha(of image: UIImage, at point: CGPoint) -> CGFloat? {
        guard let cgImage = image.cgImage else { return nil }
        let x = Int(point.x * image.scale)
        let y = Int(point.y * image.scale)
        var data = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: -x, y: y - cgImage.height + 1, width: cgImage.width, height: cgImage.height))
        return CGFloat(data[3]) / 255
    }
}
