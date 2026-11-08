@testable import fearless
import UIKit
import XCTest

/// The sun-lit redesign's pure logic: tokens, the light model, the motion policy, digit-roll planning and the
/// sync indicator. View paint is covered in `FWSunlitPaintTests`.
final class FWSunlitTests: XCTestCase {
    // MARK: - Tokens

    func testPaletteMatchesTheSpecTokenTable() {
        let expected: [(UIColor, UInt32)] = [
            (FWSunlit.Palette.background, 0x151831),
            (FWSunlit.Palette.backgroundDeep, 0x0E1024),
            (FWSunlit.Palette.brand, 0xEE0077),
            (FWSunlit.Palette.gradientStart, 0xF5046B),
            (FWSunlit.Palette.gradientEnd, 0x78003F),
            (FWSunlit.Palette.sun, 0xEE2233),
            (FWSunlit.Palette.sunRim, 0xFF3D8E),
            (FWSunlit.Palette.violet, 0x8B5CFF),
            (FWSunlit.Palette.shadow, 0x05060F),
            (FWSunlit.Palette.textPrimary, 0xEEF0FA),
            (FWSunlit.Palette.textSecondary, 0xA9AECB),
            (FWSunlit.Palette.textTertiary, 0x7F86AA),
            (FWSunlit.Palette.priceUp, 0x3DF2B0),
            (FWSunlit.Palette.priceDown, 0xFF9F57),
            (FWSunlit.Palette.success, 0x3DF2B0),
            (FWSunlit.Palette.warning, 0xFFC452),
            (FWSunlit.Palette.danger, 0xFF6B5E),
            (FWSunlit.Palette.qrField, 0xFFFFFF)
        ]
        for (color, hex) in expected {
            XCTAssertEqual(FWSunlit.hex(of: color), hex, String(format: "%06X", hex))
        }
    }

    func testTextKeepsTheSpecContrastOnBothSurfaces() {
        for surface in [FWSunlit.Palette.background, FWSunlit.Palette.backgroundDeep] {
            XCTAssertGreaterThanOrEqual(FWSunlit.contrast(FWSunlit.Palette.textPrimary, surface), 4.5)
            XCTAssertGreaterThanOrEqual(FWSunlit.contrast(FWSunlit.Palette.textSecondary, surface), 4.5)
            XCTAssertGreaterThanOrEqual(FWSunlit.contrast(FWSunlit.Palette.textTertiary, surface), 3)
            for status in [FWSunlit.Palette.success, FWSunlit.Palette.warning, FWSunlit.Palette.danger] {
                XCTAssertGreaterThanOrEqual(FWSunlit.contrast(status, surface), 4.5)
            }
        }
        // Primary buttons: white 16 pt semibold (large text) over the badge gradient.
        XCTAssertGreaterThanOrEqual(FWSunlit.contrast(.white, FWSunlit.Palette.gradientStart), 3)
        XCTAssertGreaterThanOrEqual(FWSunlit.contrast(.white, FWSunlit.color(0xB6025A)), 4.5, "gradient midpoint")
        XCTAssertEqual(FWSunlit.contrast(.black, .white), 21, accuracy: 0.01)
    }

    func testLegacyColourSetsSitOnTheSunlitPalette() {
        let expected: [(UIColor?, UInt32)] = [
            (R.color.colorBlack19(), 0x151831),
            (R.color.colorSemiBlack(), 0x151831),
            (R.color.colorBlack(), 0x0E1024),
            (R.color.colorPink(), 0xEE0077),
            (R.color.colorWhite(), 0xEEF0FA),
            (R.color.colorLightGray(), 0xA9AECB),
            (R.color.colorStrokeGray(), 0x7F86AA),
            (R.color.colorGreen(), 0x3DF2B0),
            (R.color.colorRed(), 0xFF6B5E),
            (R.color.colorYellow(), 0xFFC452)
        ]
        for (color, hex) in expected {
            let resolved = color?.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            XCTAssertEqual(resolved.flatMap(FWSunlit.hex(of:)), hex, String(format: "%06X", hex))
        }
    }

    func testChangeTintIsUpDownOrNeutral() {
        XCTAssertEqual(FWSunlit.Palette.change(0.04), FWSunlit.Palette.priceUp)
        XCTAssertEqual(FWSunlit.Palette.change(-0.76), FWSunlit.Palette.priceDown)
        XCTAssertEqual(FWSunlit.Palette.change(.zero), FWSunlit.Palette.textSecondary, "+0% is not a loss")
    }

    func testElevationShadowPairsFollowTheKeyLight() throws {
        let raised2 = try XCTUnwrap(FWSunlit.Shadows.pair(for: .raised2))
        XCTAssertEqual(raised2.highlight.offset, CGSize(width: -5, height: -5))
        XCTAssertEqual(raised2.highlight.blur, 12)
        XCTAssertEqual(raised2.highlight.opacity, 0.07, accuracy: 0.0001)
        XCTAssertEqual(raised2.key.offset, CGSize(width: 6, height: 6))
        XCTAssertEqual(raised2.key.blur, 16)
        XCTAssertEqual(raised2.key.opacity, 0.7, accuracy: 0.0001)
        XCTAssertEqual(raised2.key.layerRadius, 8)
        let raised1 = try XCTUnwrap(FWSunlit.Shadows.pair(for: .raised1))
        XCTAssertEqual(raised1.highlight.offset.width, -3, accuracy: 0.0001)
        XCTAssertEqual(raised1.key.offset.height, 3.6, accuracy: 0.0001)
        XCTAssertEqual(raised1.key.blur, 9.6, accuracy: 0.0001)
        XCTAssertEqual(raised1.key.opacity, raised2.key.opacity, "Raised-1 scales geometry, not light")
        for elevation in [FWSunlit.Elevation.flat, .inset, .emissive] {
            XCTAssertNil(FWSunlit.Shadows.pair(for: elevation))
        }
        // Highlights face the key light (up-left), shadows fall away from it (down-right).
        let light = FWSunlit.Light.keyDirection
        XCTAssertEqual(hypot(light.dx, light.dy), 1, accuracy: 0.0001)
        XCTAssertGreaterThan(raised2.highlight.offset.width * light.dx + raised2.highlight.offset.height * light.dy, 0)
        XCTAssertLessThan(raised2.key.offset.width * light.dx + raised2.key.offset.height * light.dy, 0)
        XCTAssertEqual(FWSunlit.Radius.card, 22)
        XCTAssertEqual(FWSunlit.Radius.button, 18)
        XCTAssertEqual(FWSunlit.Spacing.gutter, 20)
    }

    // MARK: - Light model

    func testSunRimFallsOffWithDistanceFromTheSun() {
        let width: CGFloat = 390
        XCTAssertEqual(FWSunlit.Light.sunRim(distance: 0, screenWidth: width), 0.35, accuracy: 0.0001)
        XCTAssertEqual(FWSunlit.Light.sunRim(distance: 0.6 * width, screenWidth: width), 0.175, accuracy: 0.0001)
        var previous = CGFloat.greatestFiniteMagnitude
        for distance in stride(from: CGFloat(0), through: 1200, by: 40) {
            let rim = FWSunlit.Light.sunRim(distance: distance, screenWidth: width)
            XCTAssertLessThanOrEqual(rim, previous)
            XCTAssertLessThanOrEqual(rim, FWSunlit.Light.maxSunRim)
            previous = rim
        }
        XCTAssertEqual(FWSunlit.Light.sunRim(distance: 3 * width, screenWidth: width), 0, "Faint rims are not drawn")
        XCTAssertEqual(FWSunlit.Light.sunRim(distance: -50, screenWidth: width), 0.35, accuracy: 0.0001)
        XCTAssertEqual(FWSunlit.Light.sunRim(distance: 10, screenWidth: 0), 0)
        XCTAssertEqual(FWSunlit.Light.sunRim(distance: .infinity, screenWidth: width), 0)
    }

    func testSunRimMeasuresToTheNearestPointOfTheTopEdge() {
        let sun = CGPoint(x: 195, y: 170)
        let hero = CGRect(x: 20, y: 80, width: 350, height: 300)
        XCTAssertEqual(FWSunlit.Light.sunRim(for: hero, sunCenter: sun, screenWidth: 390), 0.35, accuracy: 0.0001)
        let nearRow = CGRect(x: 20, y: 420, width: 350, height: 72)
        let farRow = CGRect(x: 20, y: 640, width: 350, height: 72)
        let near = FWSunlit.Light.sunRim(for: nearRow, sunCenter: sun, screenWidth: 390)
        let far = FWSunlit.Light.sunRim(for: farRow, sunCenter: sun, screenWidth: 390)
        XCTAssertEqual(near, FWSunlit.Light.sunRim(distance: 250, screenWidth: 390), accuracy: 0.0001)
        XCTAssertGreaterThan(near, far, "Rows further down the screen get less rim light")
        XCTAssertEqual(FWSunlit.Light.sunRim(for: .zero, sunCenter: sun, screenWidth: 390), 0)
    }

    func testBounceStartsAtEighteenPercentAndHalvesEverySixTenthsOfTheWidth() {
        XCTAssertEqual(FWSunlit.Light.bounce(distance: 0, screenWidth: 390), 0.18, accuracy: 0.0001)
        XCTAssertEqual(FWSunlit.Light.bounce(distance: 234, screenWidth: 390), 0.09, accuracy: 0.0001)
        XCTAssertEqual(FWSunlitBackgroundView.bounceReach, 1.44, accuracy: 0.0001)
        XCTAssertEqual(FWSunlitBackgroundView.bounceStops.first, 0)
        XCTAssertEqual(FWSunlitBackgroundView.bounceStops.last, 1)
    }

    // MARK: - Motion policy

    func testFullMotionUsesTheSpecDurations() {
        let expected: [FWMotionEvent: TimeInterval] = [
            .press: 0.09, .balanceChange: 0.45, .priceChange: 0.6, .syncRunning: 1.6, .syncFinished: 0.5,
            .syncFailed: 0.25, .listAppear: 0.22, .tabChange: 0.26, .txPending: 1.4, .txSuccess: 0.4,
            .txFailed: 0.3, .wrongPin: 0.3, .pinDigit: 0.12, .copied: 0.9
        ]
        XCTAssertEqual(Set(expected.keys), Set(FWMotionEvent.allCases))
        for (event, duration) in expected {
            XCTAssertEqual(FWMotionPolicy.full.style(for: event), .full(duration), "\(event)")
        }
        XCTAssertEqual(FWMotionPolicy.full.pressScale, 0.97)
        XCTAssertEqual(FWSunlit.Motion.pressOut, 0.16)
        XCTAssertEqual(Set(FWMotionEvent.allCases.filter(\.loops)), [.syncRunning, .txPending])
    }

    func testReducedMotionAndReducedEffectsKeepInformationWithoutMovement() {
        for policy in [FWMotionPolicy(reduceMotion: true), FWMotionPolicy(reducedEffects: true)] {
            for event in FWMotionEvent.allCases {
                switch policy.style(for: event) {
                case .full:
                    XCTFail("\(event) must not move under \(policy)")
                case let .crossfade(duration):
                    XCTAssertLessThanOrEqual(duration, FWSunlit.Motion.maxCrossfade, "\(event)")
                    XCTAssertGreaterThan(duration, 0)
                case .none:
                    XCTAssertTrue(event.loops || event == .listAppear, "\(event) keeps its information as a crossfade")
                }
            }
            XCTAssertEqual(policy.pressScale, 1)
        }
    }

    func testCalmSurfacesAnimateOnlyPressFeedback() {
        for calm in [FWMotionPolicy(calm: true), FWMotionPolicy(reduceMotion: true, calm: true)] {
            for event in FWMotionEvent.allCases {
                let style = calm.style(for: event)
                if event == .press {
                    XCTAssertEqual(style, .crossfade(FWSunlit.Motion.pressIn))
                } else {
                    XCTAssertEqual(style, .none, "\(event) never animates on signing or recovery-phrase screens")
                }
            }
        }
    }

    func testCurrentPolicyReadsEffectsSettings() throws {
        let suite = "fw-sunlit-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var system = FWEffects.SystemState()
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { system }
        XCTAssertEqual(FWMotionPolicy.current(effects: effects).isRestricted, UIAccessibility.isReduceMotionEnabled)
        system.reduceMotion = true
        effects.refresh()
        XCTAssertTrue(FWMotionPolicy.current(effects: effects).reduceMotion)
        system.reduceMotion = false
        effects.refresh()
        effects.userChoice = .reduced
        XCTAssertTrue(FWMotionPolicy.current(effects: effects).reducedEffects)
        XCTAssertTrue(FWMotionPolicy.current(effects: effects, calm: true).calm)
    }

    // MARK: - Digit roll

    func testDigitRollRollsOnlyChangedDigitsOfSameLengthValues() {
        let plan = FWDigitRoll.plan(from: "$12,814.22", to: "$13,028.30")
        XCTAssertEqual(plan.direction, .rising)
        XCTAssertEqual(plan.changed, 2 ..< 10)
        XCTAssertEqual(plan.slots, [
            .stay("$"), .stay("1"), .roll(from: "2", into: "3"), .stay(","), .roll(from: "8", into: "0"),
            .roll(from: "1", into: "2"), .roll(from: "4", into: "8"), .stay("."), .roll(from: "2", into: "3"),
            .roll(from: "2", into: "0")
        ])
    }

    func testDigitRollAlignsFromTheRightWhenTheIntegerPartGrows() {
        let plan = FWDigitRoll.plan(from: "$9,999.99", to: "$10,000.01")
        XCTAssertEqual(plan.direction, .rising)
        XCTAssertEqual(plan.slots.count, 10)
        XCTAssertEqual(plan.slots.first, .fade("$"))
        XCTAssertEqual(plan.slots[1], .fade("1"))
        XCTAssertEqual(plan.slots[2], .roll(from: "9", into: "0"))
        XCTAssertEqual(plan.slots[3], .stay(","))
        XCTAssertEqual(plan.slots[8], .roll(from: "9", into: "0"))
        XCTAssertEqual(plan.slots[9], .roll(from: "9", into: "1"))
        XCTAssertEqual(plan.changed?.upperBound, 10)
    }

    func testDigitRollReportsNoChangeAndFallingValues() {
        let same = FWDigitRoll.plan(from: "$5.00", to: "$5.00")
        XCTAssertTrue(same.isEmpty)
        XCTAssertNil(same.changed)
        XCTAssertEqual(same.direction, .none)
        let falling = FWDigitRoll.plan(from: "1.234,56 €", to: "1.234,05 €")
        XCTAssertEqual(falling.direction, .falling)
        XCTAssertEqual(falling.changed, 6 ..< 8)
        XCTAssertEqual(FWDigitRoll.plan(from: "—", to: "$1.00").direction, .none)
    }

    func testOnlyValueChangesRollNotLocaleOrCurrencySwitches() {
        XCTAssertTrue(FWDigitRoll.isSameFormat("$9,999.99", "$10,000.01"))
        XCTAssertTrue(FWDigitRoll.isSameFormat("1.234,56 €", "1.235,00 €"))
        XCTAssertFalse(FWDigitRoll.isSameFormat("$12,345.67", "12 345,67 $"))
        XCTAssertFalse(FWDigitRoll.isSameFormat("$12.00", "€12.00"))
    }

    func testNumericValueReadsGroupingAndDecimalMarks() {
        XCTAssertEqual(FWDigitRoll.numericValue("$12,814.22"), Decimal(string: "12814.22"))
        XCTAssertEqual(FWDigitRoll.numericValue("1.234,56 €"), Decimal(string: "1234.56"))
        XCTAssertEqual(FWDigitRoll.numericValue("¥1,234,567"), Decimal(string: "1234567"))
        XCTAssertEqual(FWDigitRoll.numericValue("0.5 DOT"), Decimal(string: "0.5"))
        XCTAssertEqual(FWDigitRoll.numericValue("1 234,5"), Decimal(string: "1234.5"))
        XCTAssertNil(FWDigitRoll.numericValue("—"))
    }

    // MARK: - Sync indicator

    func testSyncTrackerShowsConnectingProgressThenSynced() {
        var tracker = FWSyncTracker()
        XCTAssertEqual(tracker.state, .idle)
        tracker.balance(loading: true)
        XCTAssertEqual(tracker.state, .syncing(progress: nil))
        tracker.connection("a", .connecting)
        tracker.connection("b", .connecting)
        tracker.connection("c", .connected)
        tracker.connection("d", .connected)
        XCTAssertEqual(tracker.state, .syncing(progress: 0.5))
        tracker.balance(loading: false)
        tracker.connection("a", .connected)
        tracker.connection("b", .connected)
        XCTAssertEqual(tracker.state, .synced)
        tracker.catalogSync(running: true)
        XCTAssertEqual(tracker.state, .syncing(progress: 1))
        tracker.catalogSync(running: false)
        XCTAssertEqual(tracker.state, .synced)
    }

    func testSyncTrackerReportsUnreachableNetworksAfterSyncing() {
        var tracker = FWSyncTracker()
        tracker.connection("a", .connecting)
        tracker.connection("b", .unreachable)
        XCTAssertEqual(tracker.state, .syncing(progress: 0), "A connection still trying is still syncing")
        tracker.connection("a", .connected)
        XCTAssertEqual(tracker.state, .failed(unreachable: 1))
        XCTAssertEqual(tracker.unreachable, 1)
        tracker.connection("b", .connected)
        XCTAssertEqual(tracker.state, .synced)
    }

    func testCatalogFailureStaysVisibleUntilCatalogRetriesOrCompletes() {
        var tracker = FWSyncTracker()
        tracker.catalogSync(running: true)
        tracker.catalogFailure()
        tracker.balance(loading: true)
        XCTAssertEqual(tracker.state, .failed(unreachable: 0))
        tracker.catalogSync(running: true)
        XCTAssertEqual(tracker.state, .syncing(progress: nil))
        tracker.catalogSync(running: false)
        tracker.balance(loading: false)
        XCTAssertEqual(tracker.state, .synced)
    }

    // MARK: - List rise

    @MainActor
    func testListRiseStaggersOnlyTheFirstEightRowsOfTheFirstAppearance() throws {
        let suite = "fw-sunlit-rise-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
        var now: CFTimeInterval = 100
        let rise = FWListRise(effects: effects) { now }
        if UIAccessibility.isReduceMotionEnabled {
            XCTAssertNil(rise.delayForNextRow())
            return
        }
        let delays = (0 ..< 10).map { _ in rise.delayForNextRow() }
        for (index, delay) in delays.prefix(8).enumerated() {
            XCTAssertEqual(try XCTUnwrap(delay), Double(index) * 0.03, accuracy: 0.000_001)
        }
        XCTAssertNil(delays[8])
        XCTAssertTrue(rise.isFinished)
        now += 10
        XCTAssertNil(rise.delayForNextRow(), "Rows that appear later show at once")

        var late: CFTimeInterval = 0
        let slow = FWListRise(effects: effects) { late }
        XCTAssertEqual(slow.delayForNextRow(), 0)
        late = FWListRise.window + 0.01
        XCTAssertNil(slow.delayForNextRow())

        effects.userChoice = .reduced
        XCTAssertNil(FWListRise(effects: effects).delayForNextRow())
    }
}

/// Paint of the sun-lit surfaces: which layers light up for each elevation and setting.
@MainActor
final class FWSunlitPaintTests: XCTestCase {
    private func effects() throws -> FWEffects {
        let suite = "fw-sunlit-paint-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
    }

    private func visibleShadows(_ painter: FWSurfacePainter) -> [CALayer] {
        painter.layers.filter { !$0.isHidden && $0.shadowOpacity > 0 }
    }

    func testRaisedSurfacesCastTheKeyLightPairWithExplicitPaths() {
        let painter = FWSurfacePainter()
        let host = CALayer()
        painter.install(in: host)
        painter.layout(
            path: UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 200, height: 60), cornerRadius: 18),
            bounds: CGRect(x: 0, y: 0, width: 200, height: 60)
        )
        painter.apply(.init(elevation: .raised2, sunRim: 0.2))
        XCTAssertEqual(host.sublayers?.prefix(painter.layers.count).map { $0 }, painter.layers)
        let shadows = visibleShadows(painter)
        XCTAssertEqual(shadows.count, 2)
        XCTAssertTrue(shadows.allSatisfy { $0.shadowPath != nil })
        XCTAssertEqual(painter.keyShadow.shadowOffset, CGSize(width: 6, height: 6))
        XCTAssertEqual(painter.highlightShadow.shadowOffset, CGSize(width: -5, height: -5))
        XCTAssertTrue(painter.innerShadow.isHidden)
        XCTAssertTrue(painter.emissive.isHidden)
        XCTAssertFalse(painter.rim.isHidden)
        let top = UIColor(cgColor: (painter.rim.colors as? [CGColor] ?? [])[0])
        XCTAssertEqual(FWSunlit.hex(of: top), 0xFF3D8E, "The sun bounce tints the top rim")
        XCTAssertEqual(top.cgColor.alpha, 0.2, accuracy: 0.001)
        XCTAssertNil(host.animationKeys())
    }

    func testPressedAndInsetSurfacesSinkIntoAWell() {
        let painter = FWSurfacePainter()
        painter.install(in: CALayer())
        painter.layout(
            path: UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 60, height: 60)),
            bounds: CGRect(x: 0, y: 0, width: 60, height: 60)
        )
        painter.apply(.init(elevation: .raised2, pressed: true))
        XCTAssertEqual(visibleShadows(painter), [painter.innerShadow])
        XCTAssertEqual(painter.fill.fillColor.flatMap { FWSunlit.hex(of: UIColor(cgColor: $0)) }, 0x0E1024)
        painter.apply(.init(elevation: .inset, focused: true, interactive: true))
        XCTAssertEqual(visibleShadows(painter), [painter.innerShadow])
        XCTAssertFalse(painter.ring.isHidden)
        XCTAssertEqual(painter.ring.lineWidth, 2)
        XCTAssertEqual(painter.ring.strokeColor.flatMap { FWSunlit.hex(of: UIColor(cgColor: $0)) }, 0xEE0077)
        painter.apply(.init(elevation: .inset, error: true))
        XCTAssertEqual(painter.ring.strokeColor.flatMap { FWSunlit.hex(of: UIColor(cgColor: $0)) }, 0xFF6B5E)
    }

    func testEmissiveSurfacesGlowInTheirOwnColourWithoutAKeyShadow() {
        let painter = FWSurfacePainter()
        painter.install(in: CALayer())
        painter.layout(
            path: UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 300, height: 56), cornerRadius: 18),
            bounds: CGRect(x: 0, y: 0, width: 300, height: 56)
        )
        painter.apply(.init(elevation: .emissive))
        XCTAssertFalse(painter.emissive.isHidden)
        XCTAssertEqual(visibleShadows(painter), [painter.keyShadow])
        XCTAssertEqual(painter.keyShadow.shadowColor.flatMap { FWSunlit.hex(of: UIColor(cgColor: $0)) }, 0xEE0077)
        XCTAssertEqual(painter.keyShadow.shadowOffset, CGSize(width: 0, height: 8))
        XCTAssertTrue(painter.highlightShadow.isHidden)
    }

    func testHighContrastAndReducedPaintDropShadowsButKeepEdges() {
        let painter = FWSurfacePainter()
        painter.install(in: CALayer())
        painter.layout(
            path: UIBezierPath(rect: CGRect(x: 0, y: 0, width: 100, height: 40)),
            bounds: CGRect(x: 0, y: 0, width: 100, height: 40)
        )
        for elevation in FWSunlit.Elevation.allCases {
            painter.apply(.init(elevation: elevation, interactive: true, highContrast: true))
            XCTAssertTrue(visibleShadows(painter).isEmpty, "\(elevation)")
            XCTAssertFalse(painter.ring.isHidden)
            XCTAssertEqual(painter.ring.strokeColor?.alpha ?? 0, 0.4, accuracy: 0.001)
            painter.apply(.init(elevation: elevation, interactive: true, reduced: true))
            XCTAssertTrue(visibleShadows(painter).isEmpty, "\(elevation)")
            XCTAssertFalse(painter.rim.isHidden && painter.ring.isHidden, "Interactive controls keep an edge")
        }
    }

    func testTriangularedSurfacesRoundTheirCornersAndLightOpaqueDarkFills() {
        XCTAssertEqual(TriangularedView.automaticElevation(for: FWSunlit.Palette.background), .raised1)
        XCTAssertEqual(TriangularedView.automaticElevation(for: R.color.colorSemiBlack() ?? .clear), .raised1)
        XCTAssertNil(TriangularedView.automaticElevation(for: UIColor(white: 1, alpha: 0.08)))
        XCTAssertNil(TriangularedView.automaticElevation(for: .black), "Masks stay plain")
        XCTAssertNil(TriangularedView.automaticElevation(for: FWSunlit.Palette.brand))
        let view = TriangularedView(frame: CGRect(x: 0, y: 0, width: 300, height: 56))
        view.fillColor = FWSunlit.Palette.background
        view.layoutIfNeeded()
        XCTAssertEqual(view.resolvedCornerRadius, 18)
        XCTAssertEqual(view.resolvedElevation, .raised1)
        view.frame.size.height = 140
        XCTAssertEqual(view.resolvedCornerRadius, 22)
        view.fwElevation = .flat
        XCTAssertNil(view.resolvedElevation)
        view.frame.size.height = 20
        XCTAssertEqual(view.resolvedCornerRadius, 10, "Never more than half the height")
    }

    func testRoundActionButtonIsOneNamedButtonThatSinksWhenPressed() throws {
        let button = FWRoundActionButton(icon: R.image.iconSend(), effects: try effects())
        button.configure(title: "Send", locale: Locale(identifier: "en"))
        XCTAssertTrue(button.isAccessibilityElement)
        XCTAssertEqual(button.accessibilityLabel, "Send")
        XCTAssertTrue(button.accessibilityTraits.contains(.button))
        XCTAssertFalse(button.surface.isPressed)
        button.isHighlighted = true
        XCTAssertTrue(button.surface.isPressed)
        button.isHighlighted = false
        XCTAssertFalse(button.surface.isPressed)
        button.isEnabled = false
        XCTAssertTrue(button.accessibilityTraits.contains(.notEnabled))
    }

    func testSunBadgeShowsSyncStatesWithoutDecorativeLoops() throws {
        let badge = FWSunBadgeView(effects: try effects())
        badge.frame = CGRect(x: 0, y: 0, width: 112, height: 112)
        badge.layoutIfNeeded()
        badge.setSyncState(.idle, animated: false)
        XCTAssertTrue((badge.layer.sublayers ?? []).allSatisfy { $0.animationKeys() == nil })
        badge.setSyncState(.failed(unreachable: 2), animated: false)
        XCTAssertEqual(badge.imageView.alpha, FWSunlit.Motion.syncFailedSunAlpha, accuracy: 0.001)
        badge.setSyncState(.synced, animated: false)
        XCTAssertEqual(badge.imageView.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(badge.syncState, .synced)
    }

    func testStatusLoopsStopOffscreenAndWhenEffectsAreReduced() throws {
        let settings = try effects()
        let badge = FWSunBadgeView(effects: settings)
        let status = FWTxStatusView(effects: settings)
        let balance = FWRollingLabel(effects: settings)
        balance.frame = CGRect(x: 0, y: 0, width: 200, height: 30)
        balance.font = .systemFont(ofSize: 20)
        balance.text = "$1.00"
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.addSubview(badge)
        controller.view.addSubview(status)
        controller.view.addSubview(balance)
        balance.setText("$2.00", animated: true)
        badge.setSyncState(.syncing(progress: nil), animated: false)
        status.setStatus(.pending, animated: false)
        func hasLoop(_ view: UIView, key: String) -> Bool {
            (view.layer.sublayers ?? []).contains { $0.animation(forKey: key) != nil }
        }
        if !UIAccessibility.isReduceMotionEnabled {
            XCTAssertTrue(hasLoop(badge, key: "turn"))
            XCTAssertTrue(hasLoop(status, key: "fw.breath"))
        }
        settings.userChoice = .reduced
        XCTAssertFalse(hasLoop(badge, key: "turn"))
        XCTAssertFalse(hasLoop(status, key: "fw.breath"))
        XCTAssertFalse(balance.isAnimatingChange)
        XCTAssertEqual(balance.text, "$2.00")
        settings.userChoice = .automatic
        badge.removeFromSuperview()
        status.removeFromSuperview()
        XCTAssertFalse(hasLoop(badge, key: "turn"))
        XCTAssertFalse(hasLoop(status, key: "fw.breath"))
        XCTAssertEqual(status.status, .pending)
        XCTAssertEqual(badge.syncState, .syncing(progress: nil))
    }
}

/// The winged sun at full span on the pages with room for it.
@MainActor
final class FWWingsViewTests: XCTestCase {
    private func effects() throws -> FWEffects {
        let suite = "fw-wings-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

    private func host(_ page: UIView, width: CGFloat, height: CGFloat = 844) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let controller = UIViewController()
        controller.view = page
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    private func pages() -> [(String, () -> UIView)] {
        [
            ("unlock", { CheckPincodeViewLayout() }),
            ("welcome", { FWWelcomeView(mode: .introduction) }),
            ("wallet choice", { FWWelcomeView(mode: .walletChoice) }),
            ("start", { OnboardingStartViewLayout() }),
            ("about", { AboutViewLayout() })
        ]
    }

    func testWingsSpanMostOfEveryFullPageAtEveryPhoneWidth() throws {
        for (name, make) in pages() {
            for width: CGFloat in [320, 375, 402, 440] {
                let page = make()
                let window = try host(page, width: width)
                defer { window.isHidden = true; window.rootViewController = nil }
                let context = "\(name) at \(width)"
                let wings = try XCTUnwrap(descendants(page).compactMap { $0 as? FWWingsView }.first, context)
                XCTAssertNotNil(wings.imageView.image, context)
                XCTAssertGreaterThanOrEqual(wings.bounds.width / width, 0.8, context)
                XCTAssertEqual(wings.bounds.width / wings.bounds.height, FWWingsView.aspectRatio, accuracy: 0.03, context)
                let frame = wings.convert(wings.bounds, to: window)
                XCTAssertGreaterThanOrEqual(frame.minX, 0, context)
                XCTAssertLessThanOrEqual(frame.maxX, width, context)
                XCTAssertEqual(frame.midX, width / 2, accuracy: 1, context)
            }
        }
    }

    func testWingsStopAtTheirMaximumWidthOnATablet() throws {
        let page = CheckPincodeViewLayout()
        let window = try host(page, width: 1024, height: 1366)
        defer { window.isHidden = true; window.rootViewController = nil }
        let wings = try XCTUnwrap(descendants(page).compactMap { $0 as? FWWingsView }.first)
        XCTAssertEqual(wings.bounds.width, FWWingsView.maximumWidth, accuracy: 1)
    }

    func testArtworkMatchesTheDeclaredAspectAndIsTheWideMark() throws {
        let image = try XCTUnwrap(R.image.fwWings())
        XCTAssertEqual(image.size.width / image.size.height, FWWingsView.aspectRatio, accuracy: 0.01)
        XCTAssertEqual(image.size.width, FWWingsView.maximumWidth, accuracy: 1)
        let launch = try XCTUnwrap(R.image.logo())
        XCTAssertEqual(launch.size.width / launch.size.height, 480.0 / 200.0, accuracy: 0.01)
    }

    func testAboutListShowsTheLitPageThroughItsCells() {
        XCTAssertEqual(AboutTableViewCell(style: .default, reuseIdentifier: nil).backgroundColor, .clear)
    }

    func testGlowLeavesWithReducedEffectsAndTheMarkStays() throws {
        let settings = try effects()
        let wings = FWWingsView(effects: settings)
        XCTAssertTrue(wings.isGlowing)
        settings.userChoice = .reduced
        XCTAssertFalse(wings.isGlowing)
        XCTAssertNotNil(wings.imageView.image)
        XCTAssertEqual(wings.imageView.alpha, 1)
        settings.userChoice = .automatic
        XCTAssertTrue(wings.isGlowing)
    }
}
