@testable import fearless
import UIKit
import XCTest

@MainActor
final class FWDesignSystemTests: XCTestCase {
    private func defaults() throws -> UserDefaults {
        let name = "fw-effects-test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testAutomaticEffectsFollowPowerAndAccessibilityWithoutChangingStoredChoice() throws {
        var system = FWEffects.SystemState()
        let defaults = try defaults()
        let center = NotificationCenter()
        let effects = FWEffects(defaults: defaults, notificationCenter: center) { system }
        XCTAssertEqual(effects.tier, .full)
        XCTAssertTrue(effects.allowsLiveBlur())
        system.lowPower = true
        center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
        XCTAssertEqual(effects.tier, .lite)
        XCTAssertFalse(effects.allowsLiveBlur())
        XCTAssertFalse(effects.paintReduced())
        system.reduceTransparency = true
        center.post(name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        XCTAssertEqual(effects.tier, .reduced)
        XCTAssertTrue(effects.paintReduced())
        system.reduceTransparency = false
        system.lowPower = false
        system.highContrast = true
        center.post(name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification, object: nil)
        XCTAssertEqual(effects.tier, .reduced)
        XCTAssertTrue(effects.highContrast)
        XCTAssertEqual(effects.userChoice, .automatic)
        XCTAssertNil(defaults.object(forKey: FWEffects.preferenceKey))
        system.highContrast = false
        system.reduceMotion = true
        center.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        XCTAssertEqual(effects.tier, .full)
        XCTAssertTrue(effects.reduceMotion)
        XCTAssertTrue(effects.paintReduced(calm: true))
        XCTAssertFalse(effects.allowsLiveBlur(calm: true))
    }

    func testAccessibilityOverridesEveryChoiceAndChoicesSurviveRestart() throws {
        let defaults = try defaults()
        for choice in FWEffectsChoice.allCases {
            var system = FWEffects.SystemState()
            let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { system }
            effects.userChoice = choice
            XCTAssertEqual(effects.userChoice, choice)
            for state in [FWEffects.SystemState(reduceTransparency: true), FWEffects.SystemState(highContrast: true)] {
                system = state
                effects.refresh()
                XCTAssertEqual(effects.tier, .reduced)
                XCTAssertFalse(effects.allowsLiveBlur())
            }
            let restarted = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
            XCTAssertEqual(restarted.userChoice, choice)
            XCTAssertEqual(restarted.tier.rawValue, choice == .automatic ? "full" : choice.rawValue)
        }
    }

    func testExternalPreferenceRefreshNotifiesOnceAndInvalidValuesResolveAutomatic() throws {
        let defaults = try defaults()
        let center = NotificationCenter()
        let effects = FWEffects(defaults: defaults, notificationCenter: center) { .init(lowPower: true) }
        var changes = 0
        let observer = center.addObserver(forName: FWEffects.didChange, object: effects, queue: .main) { _ in changes += 1 }
        defer { center.removeObserver(observer) }
        defaults.set("lite", forKey: FWEffects.preferenceKey)
        center.post(name: UserDefaults.didChangeNotification, object: defaults)
        XCTAssertEqual(effects.userChoice, .lite)
        XCTAssertEqual(changes, 1, "A preference change matters even when its resolved paint is identical")
        effects.refresh()
        XCTAssertEqual(changes, 1)
        defaults.set(42, forKey: FWEffects.preferenceKey)
        effects.refresh()
        XCTAssertEqual(effects.userChoice, .automatic)
        XCTAssertEqual(changes, 2)
        effects.userChoice = .reduced
        XCTAssertEqual(effects.tier, .reduced)
        XCTAssertEqual(changes, 3)
    }

    func testEffectsAndObservedViewsDoNotRetainEachOther() throws {
        let defaults = try defaults()
        let center = NotificationCenter()
        weak var weakEffects: FWEffects?
        weak var weakGlass: FWGlassPanelView?
        weak var weakNeu: FWNeuView?
        weak var weakChrome: FWChromeBackgroundView?
        autoreleasepool {
            let effects = FWEffects(defaults: defaults, notificationCenter: center) { .init() }
            weakEffects = effects
            let glass = FWGlassPanelView(effects: effects)
            let neu = FWNeuView(effects: effects)
            let chrome = FWChromeBackgroundView(effects: effects)
            weakGlass = glass
            weakNeu = neu
            weakChrome = chrome
        }
        XCTAssertNil(weakGlass)
        XCTAssertNil(weakNeu)
        XCTAssertNil(weakChrome)
        XCTAssertNil(weakEffects)
        center.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
    }

    func testGlassPaintChangesKeepGeometryAndExplicitShadowPaths() throws {
        let effects = try FWEffects(defaults: defaults(), notificationCenter: NotificationCenter()) { .init() }
        let panel = FWGlassPanelView(frame: CGRect(x: 0, y: 0, width: 280, height: 160), effects: effects)
        panel.shape = { FWChamferPath.path(in: $0) }
        panel.layoutIfNeeded()
        let fullPath = try XCTUnwrap(panel.layer.shadowPath)
        let sublayers = try XCTUnwrap(panel.layer.sublayers)
        XCTAssertEqual(sublayers.count, 3)
        XCTAssertTrue(fullPath.contains(CGPoint(x: 140, y: 80)))
        XCTAssertFalse(fullPath.contains(CGPoint(x: 1, y: 1)))
        XCTAssertEqual(panel.layer.shadowOpacity, 0.6)
        let fill = try XCTUnwrap(sublayers.first as? CAShapeLayer)
        XCTAssertLessThan(try XCTUnwrap(fill.fillColor).alpha, 1)
        let hairline = try XCTUnwrap(sublayers.last as? CAGradientLayer)
        panel.accent = true
        XCTAssertEqual(hairline.locations, FWTokens.Gradients.accent.locations)
        effects.userChoice = .reduced
        XCTAssertEqual(panel.layer.shadowPath, fullPath)
        XCTAssertEqual(panel.layer.shadowOpacity, 0)
        XCTAssertEqual(try XCTUnwrap(fill.fillColor).alpha, 1)
        XCTAssertEqual(Set((hairline.colors as? [CGColor] ?? []).map { UIColor(cgColor: $0) }).count, 1)
        panel.bounds.size = CGSize(width: 240, height: 100)
        panel.layoutIfNeeded()
        XCTAssertEqual(panel.layer.shadowPath?.boundingBox, panel.bounds)
        XCTAssertNil(panel.layer.animationKeys())
        effects.userChoice = .automatic
        panel.calm = true
        XCTAssertEqual(panel.layer.shadowOpacity, 0)
        XCTAssertEqual(try XCTUnwrap(fill.fillColor).alpha, 1)
    }

    func testChromeRemovesLiveMaterialForLiteReducedAndCalm() throws {
        let effects = try FWEffects(defaults: defaults(), notificationCenter: NotificationCenter()) { .init() }
        let chrome = FWChromeBackgroundView(frame: CGRect(x: 0, y: 0, width: 300, height: 80), effects: effects)
        chrome.layoutIfNeeded()
        XCTAssertEqual(chrome.subviews.compactMap { $0 as? UIVisualEffectView }.count, 1)
        XCTAssertFalse(chrome.isUserInteractionEnabled)
        effects.userChoice = .lite
        chrome.layoutIfNeeded()
        XCTAssertTrue(chrome.subviews.compactMap { $0 as? UIVisualEffectView }.isEmpty)
        XCTAssertEqual(try XCTUnwrap(chrome.subviews.last?.backgroundColor?.cgColor.alpha), 0.96, accuracy: 0.01)
        effects.userChoice = .reduced
        XCTAssertEqual(chrome.subviews.last?.backgroundColor?.cgColor.alpha, 1)
        effects.userChoice = .automatic
        XCTAssertEqual(chrome.subviews.compactMap { $0 as? UIVisualEffectView }.count, 1)
        chrome.calm = true
        XCTAssertTrue(chrome.subviews.compactMap { $0 as? UIVisualEffectView }.isEmpty)
        XCTAssertEqual(chrome.subviews.last?.backgroundColor?.cgColor.alpha, 1)
    }

    func testNeumorphicWellsUsePathsAndRemoveShadowsInReducedPaint() throws {
        let effects = try FWEffects(defaults: defaults(), notificationCenter: NotificationCenter()) { .init() }
        let view = FWNeuView(frame: CGRect(x: 0, y: 0, width: 260, height: 64), effects: effects)
        view.layoutIfNeeded()
        let layers = try XCTUnwrap(view.layer.sublayers)
        XCTAssertEqual(layers.filter { $0.shadowOpacity > 0 && !$0.isHidden }.count, 2)
        for layer in layers where layer.shadowOpacity > 0 {
            XCTAssertNotNil(layer.shadowPath)
        }
        view.style = .inset
        view.controlFocused = true
        view.layoutIfNeeded()
        let rim = try XCTUnwrap(layers.last as? CAShapeLayer)
        XCTAssertEqual(rim.lineWidth, 2)
        XCTAssertEqual(layers.filter { $0.shadowOpacity > 0 && !$0.isHidden }.count, 1)
        // The inset shadow must leave the well's center at the sunken token color.
        // CALayer shadow paths use winding fill even when CAShapeLayer uses even-odd.
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.translateBy(x: -view.bounds.midX, y: -view.bounds.midY)
        view.layer.render(in: context)
        XCTAssertEqual(pixel, [6, 7, 15, 255], "An inset shadow must not cover the entire fill")
        let focus = rim.strokeColor
        view.hasError = true
        XCTAssertNotEqual(rim.strokeColor, focus)
        effects.userChoice = .reduced
        XCTAssertTrue(layers.filter { !$0.isHidden }.allSatisfy { $0.shadowOpacity == 0 })
        XCTAssertFalse(layers.compactMap { $0 as? CAGradientLayer }.allSatisfy(\.isHidden))
        view.bounds.size = CGSize(width: 200, height: 96)
        view.layoutIfNeeded()
        XCTAssertEqual(rim.path?.boundingBox, view.bounds.insetBy(dx: 1, dy: 1))
        XCTAssertNil(view.layer.animationKeys())
    }

    func testGlowHasExactPathsAndNeverSurvivesCalmOrReducedPaint() throws {
        let effects = try FWEffects(defaults: defaults(), notificationCenter: NotificationCenter()) { .init() }
        let view = UIView(frame: CGRect(x: 12, y: 20, width: 200, height: 64))
        let halo = CALayer()
        let path = FWChamferPath.path(in: view.bounds)
        FWGlow.apply(to: view, halo: halo, path: path, enabled: true, effects: effects)
        XCTAssertEqual(view.layer.shadowPath, path.cgPath)
        XCTAssertEqual(halo.shadowPath, path.cgPath)
        XCTAssertEqual(halo.frame, view.frame)
        XCTAssertGreaterThan(halo.shadowOpacity, 0)
        for style in [FWGlow.Style.pending, .focus, .success] {
            FWGlow.apply(to: view, halo: halo, path: path, style: style, enabled: true, effects: effects)
            XCTAssertGreaterThan(view.layer.shadowOpacity, 0)
            XCTAssertEqual(halo.shadowOpacity, 0)
            XCTAssertNil(view.layer.animationKeys(), "Phase 0 glow never starts an ambient animation")
        }
        FWGlow.apply(to: view, halo: halo, path: path, enabled: true, calm: true, effects: effects)
        XCTAssertEqual(view.layer.shadowOpacity, 0)
        effects.userChoice = .reduced
        FWGlow.apply(to: view, halo: halo, path: path, enabled: true, effects: effects)
        XCTAssertEqual(view.layer.shadowOpacity, 0)
        XCTAssertEqual(halo.shadowOpacity, 0)
        effects.userChoice = .automatic
        FWGlow.apply(to: view, halo: halo, path: path, enabled: false, effects: effects)
        XCTAssertEqual(view.layer.shadowOpacity, 0)
    }

    func testFontRolesScaleAndAmountsUseEqualWidthDigits() {
        let normal = UITraitCollection(preferredContentSizeCategory: .large)
        let large = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        for style in FWFontStyle.allCases {
            let font = UIFont.fw(style, compatibleWith: normal, boldText: false)
            let scaled = UIFont.fw(style, compatibleWith: large, boldText: false)
            XCTAssertGreaterThanOrEqual(font.pointSize, 12)
            XCTAssertGreaterThan(scaled.pointSize, font.pointSize)
            XCTAssertGreaterThanOrEqual(UIFont.fwLineHeight(style, compatibleWith: large), scaled.lineHeight)
        }
        for style in [FWFontStyle.displayXL, .displayL, .numberL, .numberM, .numberS] {
            let font = UIFont.fw(style, compatibleWith: normal, boldText: false)
            XCTAssertEqual(
                ("11111" as NSString).size(withAttributes: [.font: font]).width,
                ("88888" as NSString).size(withAttributes: [.font: font]).width,
                accuracy: 0.1
            )
            XCTAssertFalse(font.fontName.localizedCaseInsensitiveContains("mono"))
            XCTAssertFalse(font.fontName.localizedCaseInsensitiveContains("sora"))
        }
        XCTAssertGreaterThan(
            UIFont.fwLineHeight(.bodyL, calm: true, compatibleWith: normal),
            UIFont.fwLineHeight(.bodyL, compatibleWith: normal)
        )
    }

    func testNonLatinTitlesAndCJKHudUseBodyFaceAndBoldTextChangesWeight() {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        for language in ["ru", "vi", "ja", "zh-Hans"] {
            for role in [FWFontStyle.titleL, .titleM] {
                let font = UIFont.fw(role, locale: Locale(identifier: language), compatibleWith: traits)
                XCTAssertFalse(font.fontName.localizedCaseInsensitiveContains("sora"))
            }
        }
        for language in ["ja", "zh-Hans"] {
            let font = UIFont.fw(.hud, locale: Locale(identifier: language), compatibleWith: traits)
            XCTAssertFalse(font.fontName.localizedCaseInsensitiveContains("mono"))
        }
        for role in [FWFontStyle.bodyM, .numberM, .titleS, .monoM, .hud] {
            let regular = UIFont.fw(role, compatibleWith: traits, boldText: false)
            let bold = UIFont.fw(role, compatibleWith: traits, boldText: true)
            XCTAssertEqual(regular.pointSize, bold.pointSize)
            XCTAssertNotEqual(regular.fontDescriptor, bold.fontDescriptor)
        }
    }
}

extension FWDesignSystemTests {
    func testBackgroundDefaultsChangeNeverWaitsForTheMainThread() throws {
        let defaults = try defaults()
        let center = NotificationCenter()
        let effects = FWEffects(defaults: defaults, notificationCenter: center) { .init() }
        defaults.set("lite", forKey: FWEffects.preferenceKey)
        let posted = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            center.post(name: UserDefaults.didChangeNotification, object: defaults)
            posted.signal()
        }

        // The main thread waits here as it would for a lock the posting thread holds: the post must not wait for it.
        XCTAssertEqual(posted.wait(timeout: .now() + 5), .success)
        let refreshed = expectation(description: "the refresh runs on the main thread")
        DispatchQueue.main.async { refreshed.fulfill() }
        wait(for: [refreshed], timeout: 5)
        XCTAssertEqual(effects.userChoice, .lite)
    }
}
