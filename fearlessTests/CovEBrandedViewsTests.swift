@testable import fearless
import SoraUI
import UIKit
import XCTest

@MainActor
final class CovEBrandedViewsTests: XCTestCase {
    func testDialAndLoaderStopMotionForKnownProgressAndReducedEffects() throws {
        let fixture = try CovEEffectFixture()
        let dial = FWSyncDialView(effects: fixture.effects)
        let window = CovEHost.window(for: dial, frame: CGRect(x: 16, y: 100, width: 32, height: 32))
        defer { CovEHost.close(window) }
        XCTAssertTrue(dial.isCometRunning)
        dial.set(.counts(done: 2, failed: 1, total: 5), animated: true)
        XCTAssertEqual(dial.model.countText, "2 / 5")
        XCTAssertTrue(dial.isCometRunning)
        dial.set(.counts(done: 4, failed: 1, total: 5), animated: true)
        XCTAssertNil(dial.model.countText)
        XCTAssertFalse(dial.isCometRunning)
        XCTAssertTrue(CovELayers.all(in: dial.layer).contains { $0.animation(forKey: FWSyncDialView.sealKey) != nil })
        dial.set(.settled, animated: false)
        XCTAssertTrue(dial.model.state.phase.isSettled)
        let loader = FWMirrorLoaderView(effects: fixture.effects)
        let second = CovEHost.window(for: loader, frame: CGRect(x: 16, y: 200, width: 96, height: 96))
        defer { CovEHost.close(second) }
        XCTAssertTrue(loader.isRunning)
        let fill = try XCTUnwrap(loader.layer.sublayers?[5] as? CAShapeLayer)
        for (progress, expected) in [(-1.0, 0.001), (0.5, 0.5), (2.0, 1.0)] {
            loader.progress = progress
            XCTAssertEqual(fill.strokeEnd, expected, accuracy: 0.0001)
            XCTAssertFalse(loader.isRunning)
        }
        loader.progress = nil
        XCTAssertTrue(loader.isRunning)
        fixture.effects.userChoice = .reduced
        XCTAssertFalse(loader.isRunning)
        XCTAssertTrue(CovELayers.all(in: loader.layer).contains { $0.animation(forKey: FWMirrorLoaderView.restKey) != nil })
        dial.set(.busy, animated: false)
        XCTAssertFalse(dial.isCometRunning)
        XCTAssertFalse(dial.isMotionAllowed)
        loader.removeFromSuperview()
        XCTAssertFalse(CovELayers.all(in: loader.layer).contains { $0.animation(forKey: FWMirrorLoaderView.restKey) != nil })
    }

    func testSkyCardMarksRimAndBadgeReflectSyncAndEffects() throws {
        let fixture = try CovEEffectFixture()
        let sky = FWSkyCardView(effects: fixture.effects)
        sky.sunCenter = CGPoint(x: 100, y: 70)
        sky.textTop = 100
        sky.drift = 100
        let window = CovEHost.window(for: sky, frame: CGRect(x: 16, y: 100, width: 350, height: 220))
        defer { CovEHost.close(window) }
        XCTAssertEqual(sky.clipView.frame, sky.bounds)
        XCTAssertTrue(sky.skyView.frame.contains(sky.bounds))
        XCTAssertEqual(sky.geometryView.center, CGPoint(x: 100, y: 70))
        XCTAssertTrue(sky.geometryView.isTurning)
        XCTAssertTrue(sky.marks.isBandMoving)
        XCTAssertNotNil(sky.marks.brackets.path)
        XCTAssertNotNil(sky.marks.lattice.path)
        sky.pulse()
        XCTAssertTrue(CovELayers.all(in: sky.layer).contains { !($0.animationKeys() ?? []).isEmpty })
        let normal = FWSkyCardView.skyFrame(in: sky.bounds, imageSize: CGSize(width: 1200, height: 675), sun: .zero, drift: 10)
        XCTAssertEqual(normal, FWSkyCardView.skyFrame(in: sky.bounds, imageSize: CGSize(width: 1200, height: 675), sun: .zero, drift: 100))
        let badge = FWSunBadgeView(effects: fixture.effects)
        let second = CovEHost.window(for: badge, frame: CGRect(x: 16, y: 350, width: 96, height: 96))
        defer { CovEHost.close(second) }
        let arc = try XCTUnwrap(CovEFind.mirror(badge, "arc", as: CAGradientLayer.self))
        badge.setSyncState(.syncing(progress: 0.25), animated: false)
        XCTAssertEqual((arc.mask as? CAShapeLayer)?.strokeEnd, 0.25)
        XCTAssertNotNil(arc.animation(forKey: "turn"))
        badge.setSyncState(.synced, animated: true)
        XCTAssertTrue(CovELayers.all(in: badge.layer).contains { $0.animation(forKey: "bloom") != nil })
        badge.setSyncState(.failed(unreachable: 2), animated: false)
        XCTAssertEqual(badge.imageView.alpha, FWSunlit.Motion.syncFailedSunAlpha, accuracy: 0.0001)
        badge.setSyncState(.idle, animated: false)
        XCTAssertEqual(badge.imageView.alpha, 1)
        badge.showsSyncArc = false
        badge.setSyncState(.syncing(progress: nil), animated: false)
        XCTAssertTrue(arc.isHidden)
        fixture.effects.userChoice = .reduced
        badge.calm = true
        XCTAssertEqual(badge.imageView.layer.shadowOpacity, 0)
        XCTAssertFalse(sky.marks.isBandMoving)
        sky.removeFromSuperview()
        XCTAssertFalse(sky.geometryView.isTurning)
    }

    func testRoundAndWelcomeButtonsExposeTitlesPressStateAndDisabledAppearance() throws {
        let fixture = try CovEEffectFixture()
        let button = FWRoundActionButton(icon: R.image.iconClose(), effects: fixture.effects)
        button.configure(title: "Receive tokens", locale: Locale(identifier: "en"))
        button.emissive = true
        button.sheen = true
        button.sunRim = 0.5
        let window = CovEHost.window(for: button, frame: CGRect(x: 16, y: 100, width: 120, height: 100))
        defer { CovEHost.close(window) }
        XCTAssertEqual(button.accessibilityLabel, "Receive tokens")
        XCTAssertEqual(button.titleLabel.text, "Receive tokens")
        XCTAssertEqual(button.sunRim, 0.5)
        XCTAssertTrue(CovELayers.all(in: button.layer).contains { $0.animation(forKey: "fw.sheen") != nil })
        button.isHighlighted = true
        XCTAssertTrue(button.surface.isPressed)
        XCTAssertEqual(button.surface.transform.a, FWRoundActionButton.pressedScale, accuracy: 0.001)
        button.isHighlighted = false
        XCTAssertFalse(button.surface.isPressed)
        XCTAssertTrue(button.surface.transform.isIdentity)
        button.isEnabled = false
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
        XCTAssertEqual(button.iconView.tintColor, FWSunlit.Palette.textTertiary)
        XCTAssertFalse(CovELayers.all(in: button.layer).contains { $0.animation(forKey: "fw.sheen") != nil })
        for style in [FWWelcomeActionButton.Style.primary, .secondary, .link] {
            let welcome = FWWelcomeActionButton(style: style, effects: fixture.effects)
            welcome.configure(title: "Start a new wallet", locale: Locale(identifier: "en"))
            let hosted = CovEHost.window(for: welcome, frame: CGRect(x: 16, y: 250, width: 330, height: 64))
            defer { CovEHost.close(hosted) }
            XCTAssertEqual(welcome.label.attributedText?.string, "Start a new wallet")
            XCTAssertEqual(welcome.accessibilityLabel, "Start a new wallet")
            welcome.isHighlighted = true
            welcome.layoutIfNeeded()
            XCTAssertEqual(welcome.label.textColor, style == .primary ? .white : FWSunlit.Palette.textPrimary)
            welcome.isHighlighted = false
            XCTAssertTrue(welcome.transform.isIdentity)
        }
        let icon = FWRoundIconButton.make(image: R.image.iconClose())
        icon.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        icon.layoutIfNeeded()
        icon.sendActions(for: .touchDown)
        XCTAssertTrue(try XCTUnwrap(CovEFind.first(FWNeuView.self, in: icon)).isPressed)
        icon.sendActions(for: .touchCancel)
        XCTAssertFalse(try XCTUnwrap(CovEFind.first(FWNeuView.self, in: icon)).isPressed)
    }

    func testTransactionStatusDrawsSuccessAndFailureOnlyForLiveChanges() throws {
        let fixture = try CovEEffectFixture()
        let view = FWTxStatusView(effects: fixture.effects)
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 24, height: 24))
        defer { CovEHost.close(window) }
        view.setStatus(.pending, animated: false)
        XCTAssertTrue(CovELayers.all(in: view.layer).contains { $0.animation(forKey: "fw.breath") != nil })
        view.setStatus(.success, animated: true)
        XCTAssertEqual(view.status, .success)
        XCTAssertTrue(CovELayers.all(in: view.layer).contains { $0.animation(forKey: "fw.draw") != nil })
        view.setStatus(.pending, animated: false)
        view.setStatus(.failed, animated: true)
        XCTAssertNotNil(view.layer.animation(forKey: "fw.shake"))
        view.setStatus(.failed, animated: false)
        XCTAssertNil(view.layer.animation(forKey: "fw.shake"))
        fixture.effects.userChoice = .reduced
        view.setStatus(.pending, animated: false)
        view.setStatus(.success, animated: true)
        XCTAssertFalse(CovELayers.all(in: view.layer).contains { $0.animation(forKey: "fw.breath") != nil })
        XCTAssertNotNil(view.layer.animation(forKey: "fw.fade"))
    }

    func testPinStylingIsIdempotentAndDotsFollowTheNativeField() throws {
        let fixture = try CovEEffectFixture()
        let pin = PinView()
        pin.mode = .securedInput
        let window = CovEHost.window(for: pin, frame: CGRect(x: 20, y: 100, width: 350, height: 500))
        defer { CovEHost.close(window) }
        let styler = FWPinPadStyler(pinView: pin, effects: fixture.effects)
        styler.apply(textColor: .yellow)
        pin.layoutIfNeeded()
        let fields = try XCTUnwrap(pin.securedCharacterFieldsView)
        let dots = try XCTUnwrap(CovEFind.first(FWPinDotsView.self, in: fields))
        let count = CovEFind.all(FWNeuView.self, in: pin).count
        styler.apply()
        XCTAssertEqual(CovEFind.all(FWNeuView.self, in: pin).count, count)
        XCTAssertEqual(pin.errorAnimationAmplitude, FWSunlit.Motion.shakeDistance)
        styler.applySunRim(sunCenter: CGPoint(x: 175, y: 50), in: pin)
        let key = try XCTUnwrap(pin.numpadView?.subviews.compactMap { $0 as? RoundedButton }.first {
            $0.imageWithTitleView?.title == "1"
        })
        let surface = try XCTUnwrap(CovEFind.first(FWNeuView.self, in: key))
        key.sendActions(for: .touchDown)
        XCTAssertTrue(surface.isPressed)
        key.sendActions(for: .touchCancel)
        XCTAssertFalse(surface.isPressed)
        fields.set(newCharacters: ["1", "2"])
        XCTAssertTrue(CovEHost.spin(until: {
            dots.layer.sublayers?.compactMap { $0 as? CAGradientLayer }.filter { $0.opacity == 1 }.count == 2
        }))
        fields.clear()
        XCTAssertTrue(CovEHost.spin(until: {
            dots.layer.sublayers?.compactMap { $0 as? CAGradientLayer }.allSatisfy { $0.opacity == 0 } == true
        }))
        fixture.effects.userChoice = .reduced
        styler.apply()
        XCTAssertEqual(pin.errorAnimationAmplitude, 0)
    }

    func testPanelsChromeAndTabWellAdaptWithoutChangingGeometry() throws {
        let fixture = try CovEEffectFixture()
        let panel = FWGlassPanelView(effects: fixture.effects)
        panel.accent = true
        let window = CovEHost.window(for: panel, frame: CGRect(x: 16, y: 100, width: 300, height: 100))
        defer { CovEHost.close(window) }
        XCTAssertNotNil(panel.layer.shadowPath)
        XCTAssertEqual(panel.layer.shadowOpacity, 0.6)
        panel.calm = true
        XCTAssertEqual(panel.layer.shadowOpacity, 0)
        XCTAssertEqual(panel.bounds.size, CGSize(width: 300, height: 100))
        let chrome = FWChromeBackgroundView(effects: fixture.effects)
        chrome.frame = panel.bounds
        panel.addSubview(chrome)
        chrome.layoutIfNeeded()
        XCTAssertFalse(CovEFind.all(UIVisualEffectView.self, in: chrome).isEmpty)
        fixture.effects.userChoice = .reduced
        chrome.calm = true
        XCTAssertTrue(CovEFind.all(UIVisualEffectView.self, in: chrome).isEmpty)
        let well = FWTabWellView(effects: fixture.effects)
        panel.addSubview(well)
        well.move(to: CGPoint(x: 40, y: 40), visible: true, animated: false)
        well.layoutIfNeeded()
        XCTAssertEqual(well.center, CGPoint(x: 40, y: 40))
        XCTAssertFalse(well.well.isHidden)
        well.systemDrawsSelection = true
        well.layoutIfNeeded()
        XCTAssertTrue(well.well.isHidden)
        XCTAssertEqual(well.dot.frame.minY, 3)
        well.move(to: CGPoint(x: 80, y: 40), visible: false, animated: true)
        XCTAssertTrue(CovEHost.spin(until: { well.center.x == 80 && well.alpha == 0 }))
    }
}
