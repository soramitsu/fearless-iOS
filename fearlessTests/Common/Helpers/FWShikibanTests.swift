@testable import fearless
import UIKit
import XCTest

/// Brand kit v4, "Shikiban": the ported formulas against the bundled `shikiban.json` (its sampled keyframes are the
/// kit's own evaluation of the same formulas), the launch flight and later arrivals, the sync dial, the seal, the
/// loader and the hero's marks.
final class FWShikibanTokenTests: XCTestCase {
    private func tokens() throws -> FWShikiban {
        try XCTUnwrap(FWShikiban.bundled, "shikiban.json must ship in the app bundle")
    }

    func testBundledTokensAreTheKitV4Tokens() throws {
        let tokens = try tokens()
        XCTAssertEqual(tokens.formatVersion, 1)
        XCTAssertEqual(tokens.perspective, 900)
        XCTAssertEqual(tokens.durationsMs, [90, 128, 180, 255, 360, 510, 720, 1020])
        XCTAssertEqual(tokens.gates.count, 6)
        XCTAssertTrue(tokens.gates.last?.isMirror ?? false)
        XCTAssertEqual(tokens.gates.filter(\.isMirror).count, 1)
        XCTAssertEqual(tokens.flight.durationMs, 1270)
        XCTAssertEqual(tokens.flight.irisAtMs, 550)
        XCTAssertEqual(tokens.flight.skipMs, 510)
        XCTAssertEqual(tokens.flight.landingMs, 510)
        XCTAssertEqual(tokens.flight.baseRadius, 0.47, accuracy: 1e-9)
        XCTAssertEqual(tokens.flight.corona.count, 5)
        XCTAssertEqual(tokens.flight.corona.first?.offset, 0)
        XCTAssertEqual(tokens.flight.corona.last?.offset, 1)
        XCTAssertEqual(tokens.mirror.rim.count, 8)
        XCTAssertEqual(tokens.mirror.cusp, cos(Double.pi / 8), accuracy: 1e-5)
        XCTAssertEqual(tokens.dial.segments, 8)
        XCTAssertEqual(tokens.loader.comets, 3)
        XCTAssertEqual(tokens.seal.stages, ["ready", "signed", "sent", "accepted"])
        XCTAssertEqual(tokens.colors.flight, "#38E8E0")
        XCTAssertEqual(tokens.colors.failure, "#FF5A4D")
    }

    func testTheDepthLawAndTheAdQuadratumStart() throws {
        let tokens = try tokens()
        XCTAssertEqual(tokens.depthScale(0), 1)
        XCTAssertEqual(tokens.depthScale(900), 0.5)
        // From the camera's start, gate i's scale is (1/√2)^i: the flat ad quadratum figure.
        for index in tokens.gates.indices {
            XCTAssertEqual(tokens.gateScale(index, 0), pow(2.0.squareRoot(), -Double(index)), accuracy: 1e-4)
            XCTAssertEqual(tokens.gateScale(index, 0), tokens.ratio.ladder[index], accuracy: 1e-4)
        }
    }

    func testCameraIrisGatesAndAlphaMatchTheKitSamples() throws {
        let tokens = try tokens()
        let samples = tokens.flight.samples
        for step in 0 ... 24 {
            let u = Double(step) / 24
            XCTAssertEqual(tokens.cameraAt(u), samples.camera[step], accuracy: 1e-3, "camera at \(u)")
            XCTAssertEqual(tokens.irisScale(u), samples.iris[step], accuracy: 1e-4, "iris at \(u)")
            for gate in tokens.gates.indices {
                XCTAssertEqual(tokens.gateScale(gate, u), samples.gates[gate][step], accuracy: 1e-4, "gate \(gate) at \(u)")
                XCTAssertEqual(tokens.gateAlpha(gate, u), samples.gateAlpha[gate][step], accuracy: 1e-4, "alpha \(gate) at \(u)")
            }
        }
    }

    func testTierScalesMatchTheSamplesAndEndAtExactlyOne() throws {
        let tokens = try tokens()
        for tier in 0 ..< tokens.flight.samples.tiers.count {
            var previous = 0.0
            for step in 0 ... 24 {
                let u = Double(step) / 24
                let scale = tokens.tierScale(tier, u)
                XCTAssertEqual(scale, tokens.flight.samples.tiers[tier][step], accuracy: 1e-4, "tier \(tier) at \(u)")
                XCTAssertGreaterThanOrEqual(scale, previous)
                XCTAssertLessThanOrEqual(scale, 1)
                previous = scale
            }
            XCTAssertEqual(tokens.tierScale(tier, 1), 1, "tier \(tier) must land at exactly 1")
            XCTAssertLessThan(tokens.tierScale(tier, 0.98), 1)
            if tier > 0 {
                // Farther tiers lag: the screen comes apart in depth on the way.
                XCTAssertLessThan(tokens.tierScale(tier, 0.7), tokens.tierScale(tier - 1, 0.7))
            }
        }
    }

    func testLandingStartsAtLandingFromAndSettlesAtOne() throws {
        let tokens = try tokens()
        for (tier, from) in tokens.flight.landingFrom.enumerated() {
            XCTAssertEqual(tokens.landingScale(tier, 0), from, accuracy: 1e-4)
            XCTAssertEqual(tokens.landingScale(tier, 1), 1)
            let start = FWLanding.state(tier: tier, atMs: 0, tokens: tokens)
            XCTAssertEqual(start.scale, from, accuracy: 1e-4)
            XCTAssertEqual(start.opacity, 0)
            let end = FWLanding.state(tier: tier, atMs: FWLanding.totalMs(maxTier: 5, tokens: tokens), tokens: tokens)
            XCTAssertEqual(end.scale, 1)
            XCTAssertEqual(end.opacity, 1)
            // Tier k starts k × 45 ms later and is fully opaque 45 % into its own landing.
            let opaque = FWLanding.state(tier: tier, atMs: Double(tier) * 45 + 510 * 0.45, tokens: tokens)
            XCTAssertEqual(opaque.opacity, 1, accuracy: 1e-9)
        }
    }

    func testEasingsAndSmootherstep() throws {
        let tokens = try tokens()
        XCTAssertEqual(FWShikiban.smootherstep(0), 0)
        XCTAssertEqual(FWShikiban.smootherstep(0.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(FWShikiban.smootherstep(1), 1)
        let settle = tokens.settle
        XCTAssertEqual(settle(0), 0)
        XCTAssertEqual(settle(1), 1)
        XCTAssertGreaterThan(settle(0.5), 0.85, "settle arrives early and rests")
        var previous = 0.0
        for step in 1 ... 50 {
            let value = settle(Double(step) / 50)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-9)
            previous = value
        }
    }

    func testTheMirrorOpensAtIrisTimeAndClearsAPhoneBeforeTheFlightEnds() throws {
        let tokens = try tokens()
        let bounds = CGRect(x: 0, y: 0, width: 402, height: 874)
        let focus = FWLaunchTimeline.focusPoint(in: bounds, focus: FWLaunchTimeline.kitV3.focus.phone)
        let far = FWLaunchFlight.farthestCorner(from: focus, in: bounds)
        XCTAssertEqual(tokens.irisRadius(atMs: 549, side: 402), 0)
        XCTAssertGreaterThan(tokens.irisRadius(atMs: 560, side: 402), 0)
        XCTAssertLessThan(tokens.irisRadius(atMs: 560, side: 402), tokens.irisRadius(atMs: 730, side: 402))
        XCTAssertGreaterThan(Double(far), tokens.irisRadius(atMs: 900, side: 402), "the wallet is still seen through it")
        XCTAssertGreaterThan(tokens.irisRadius(atMs: 1200, side: 402), Double(far), "cleared before the flight ends")
        XCTAssertEqual(FWShikiban.gateWidth(scale: 0.1), 1.09, accuracy: 1e-9)
        XCTAssertEqual(FWShikiban.gateWidth(scale: 9), 4.5)
        XCTAssertEqual(tokens.skipRate, 1270.0 / 510.0, accuracy: 1e-9)
    }

    func testTiersFadeInFromTheOpeningWithTheirStagger() throws {
        let tokens = try tokens()
        XCTAssertEqual(tokens.tierOpacity(0, atMs: 550), 0)
        XCTAssertEqual(tokens.tierOpacity(0, atMs: 640), 0.5, accuracy: 1e-9)
        XCTAssertEqual(tokens.tierOpacity(0, atMs: 730), 1)
        XCTAssertEqual(tokens.tierOpacity(4, atMs: 730), 0)
        XCTAssertEqual(tokens.tierOpacity(4, atMs: 910), 1)
        XCTAssertEqual(tokens.tierOpacity(5, atMs: 1270), 1)
    }
}

// MARK: - The launch flight and arrivals

final class FWLaunchFlightTests: XCTestCase {
    private var root: UIView!
    private var cover: UIView!
    private var card: UIView!
    private var list: UIView!
    private var segment: UIView!

    override func setUp() {
        super.setUp()
        root = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        cover = UIView(frame: root.bounds)
        card = UIView(frame: CGRect(x: 16, y: 120, width: 370, height: 220))
        list = UIView(frame: CGRect(x: 0, y: 500, width: 402, height: 300))
        segment = UIView(frame: CGRect(x: 16, y: 10, width: 370, height: 40))
        segment.alpha = 0.8
        list.addSubview(segment)
        root.addSubview(card)
        root.addSubview(list)
        root.addSubview(cover)
    }

    private var focus: CGPoint {
        FWLaunchTimeline.focusPoint(in: root.bounds, focus: FWLaunchTimeline.kitV3.focus.phone)
    }

    private func makeFlight(
        feedback: FeedbackRecorder,
        cleared: @escaping () -> Void = {},
        finished: @escaping () -> Void = {}
    ) throws -> FWLaunchFlight {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        return FWLaunchFlight(
            tokens: tokens, cover: cover,
            tiers: [FWFlightTier(view: card, tier: 0), FWFlightTier(view: list, tier: 4), FWFlightTier(view: segment, tier: 3)],
            focus: focus, feedback: feedback, onCleared: cleared, onFinished: finished
        )
    }

    /// Where a view's own point lands on screen through its transform (and its parent's).
    private func screenPoint(of point: CGPoint, in view: UIView) -> CGPoint {
        view.convert(point, to: root)
    }

    func testTiersFlyUpAboutTheFocusAndEndAtRestWithNothingLeftOnThem() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let feedback = FeedbackRecorder()
        var clearedCount = 0, finishedCount = 0
        let flight = try makeFlight(feedback: feedback, cleared: { clearedCount += 1 }, finished: { finishedCount += 1 })
        flight.advance(byMs: 0)
        XCTAssertEqual(card.alpha, 0, "tiers are unseen until the mirror opens")
        XCTAssertEqual(Double(card.transform.a), tokens.tierScale(0, 0), accuracy: 1e-6)
        flight.advance(byMs: 635)
        let u = 635.0 / 1270
        XCTAssertEqual(Double(card.transform.a), tokens.tierScale(0, u), accuracy: 1e-6)
        XCTAssertEqual(Double(list.transform.a), tokens.tierScale(4, u), accuracy: 1e-6)
        // The nested tier reads as its own scale on screen: its parent's scale times its local ratio.
        XCTAssertEqual(Double(segment.transform.a * list.transform.a), tokens.tierScale(3, u), accuracy: 1e-6)
        // A scale about the focus keeps the focus where it is.
        let focusInCard = root.convert(focus, to: card)
        let cardCenter = CGPoint(x: card.bounds.midX, y: card.bounds.midY)
        let moved = CGPoint(
            x: cardCenter.x + (focusInCard.x - cardCenter.x) * card.transform.a + card.transform.tx,
            y: cardCenter.y + (focusInCard.y - cardCenter.y) * card.transform.d + card.transform.ty
        )
        XCTAssertEqual(moved.x, focusInCard.x, accuracy: 0.01)
        XCTAssertEqual(moved.y, focusInCard.y, accuracy: 0.01)
        XCTAssertTrue(feedback.played.isEmpty)
        flight.advance(byMs: 400)
        XCTAssertEqual(feedback.played, [.launchArrive], "launchArrive at 1000 ms into the flight")
        XCTAssertNotNil(cover.layer.mask, "the opening is cut through the overlay")
        flight.advance(byMs: 300)
        XCTAssertTrue(flight.isFinished)
        XCTAssertEqual(clearedCount, 1)
        XCTAssertEqual(finishedCount, 1)
        XCTAssertEqual(feedback.played, [.launchArrive])
        for view in [card, list, segment] {
            XCTAssertEqual(view?.transform, .identity)
        }
        XCTAssertEqual(card.alpha, 1)
        XCTAssertEqual(segment.alpha, 0.8, accuracy: 1e-6, "a view's own opacity comes back")
    }

    func testTheOverlayIsReleasedWhenTheOpeningClearsTheViewBeforeTheTiersLand() throws {
        var clearedAt: Double?
        var flight: FWLaunchFlight?
        flight = try makeFlight(feedback: FeedbackRecorder(), cleared: { clearedAt = flight?.elapsedMs })
        for _ in 0 ..< 80 {
            flight?.advance(byMs: 16)
        }
        let at = try XCTUnwrap(clearedAt)
        XCTAssertGreaterThan(at, 550)
        XCTAssertLessThan(at, 1270)
    }

    func testASkipPlaysTheRestTwoAndAHalfTimesFaster() throws {
        let flight = try makeFlight(feedback: FeedbackRecorder())
        flight.advance(byMs: 100)
        flight.skip()
        XCTAssertEqual(flight.rate, 1270.0 / 510.0, accuracy: 1e-9)
        flight.advance(byMs: 400)
        XCTAssertFalse(flight.isFinished)
        flight.advance(byMs: 70)
        XCTAssertTrue(flight.isFinished, "100 ms plus 470 ms at 2.49× covers the whole 1270 ms")
        XCTAssertEqual(card.transform, .identity)
    }

    func testCancelRestoresTheTiersWithoutTheArrivalTouch() throws {
        let feedback = FeedbackRecorder()
        let flight = try makeFlight(feedback: feedback)
        flight.advance(byMs: 700)
        flight.cancel()
        XCTAssertEqual(card.transform, .identity)
        XCTAssertEqual(card.alpha, 1)
        XCTAssertTrue(feedback.played.isEmpty)
    }

    func testAScreenPutInPlaceMidFlightFliesFromThere() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let replacement = UIView(frame: CGRect(x: 0, y: 200, width: 402, height: 300))
        root.addSubview(replacement)
        let splash = NSObject(), welcome = NSObject()
        var current: NSObject = splash
        let flight = try makeFlight(feedback: FeedbackRecorder())
        flight.currentScreen = { (ObjectIdentifier(current), { [FWFlightTier(view: replacement, tier: 0)] }) }
        flight.advance(byMs: 300)
        XCTAssertEqual(replacement.transform, .identity)
        current = welcome
        flight.advance(byMs: 335)
        XCTAssertEqual(card.transform, .identity, "the old screen is left at rest")
        XCTAssertEqual(Double(replacement.transform.a), tokens.tierScale(0, 635.0 / 1270), accuracy: 1e-6)
        flight.advance(byMs: 1000)
        XCTAssertEqual(replacement.transform, .identity)
    }

    func testTheWelcomeDeclaresItsMarkMainControlAndRest() throws {
        final class Output: OnboardingStartViewOutput {
            func didLoad(view _: OnboardingStartViewInput) {}
            func didTapStartButton() {}
        }
        let output = Output()
        let controller = OnboardingStartViewController(
            output: output, localizationManager: nil, welcomeAppearanceEnabled: true
        )
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = root.bounds
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        let tiers = FWFlightTierFinder.tiers(in: controller)
        let welcome = try XCTUnwrap(controller.welcomeView)
        XCTAssertTrue(tiers.contains { $0.view === welcome.lockup && $0.tier == 0 })
        XCTAssertTrue(tiers.contains { $0.view === welcome.primaryButton && $0.tier == 1 })
        XCTAssertFalse(tiers.contains { $0.view === controller.view }, "not one piece")
    }

    func testAScreenThatDeclaresNothingFliesAsOnePiece() {
        let controller = UIViewController()
        controller.loadViewIfNeeded()
        let window = UIWindow(frame: root.bounds)
        window.rootViewController = controller
        window.isHidden = false
        let tiers = FWFlightTierFinder.tiers(in: controller)
        XCTAssertEqual(tiers.count, 1)
        XCTAssertTrue(tiers.first?.view === controller.view)
        XCTAssertEqual(tiers.first?.tier, 0)
        window.isHidden = true
    }

    func testTheLaterArrivalAnimatesFromLandingFromAndLeavesTheModelUntouched() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        FWLanding.animate(tiers: [FWFlightTier(view: card, tier: 0), FWFlightTier(view: list, tier: 4)], focus: focus, tokens: tokens)
        let animation = try XCTUnwrap(card.layer.animation(forKey: FWLanding.animationKey) as? CAAnimationGroup)
        XCTAssertEqual(animation.duration, FWLanding.totalMs(maxTier: 4, tokens: tokens) / 1000, accuracy: 1e-9)
        let move = try XCTUnwrap(animation.animations?.first as? CAKeyframeAnimation)
        let first = try XCTUnwrap(move.values?.first as? NSValue).caTransform3DValue
        let last = try XCTUnwrap(move.values?.last as? NSValue).caTransform3DValue
        XCTAssertEqual(Double(first.m11), tokens.flight.landingFrom[0], accuracy: 1e-4)
        XCTAssertTrue(CATransform3DIsIdentity(last))
        XCTAssertEqual(card.transform, .identity)
        XCTAssertNotNil(list.layer.animation(forKey: FWLanding.animationKey))
    }

    func testReducedMotionLandsWithoutTheTierMotion() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let defaults = UserDefaults(suiteName: "FWLaunchFlightTests.reduced")!
        defaults.removePersistentDomain(forName: "FWLaunchFlightTests.reduced")
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) {
            FWEffects.SystemState(reduceMotion: true)
        }
        let window = UIWindow(windowScene: scene)
        window.frame = root.bounds
        window.isHidden = false
        defer { window.isHidden = true }
        let controller = UIViewController()
        FWLandingAnimationCoordinator(effects: effects).animateTransition(to: controller, in: window)
        XCTAssertTrue(window.rootViewController === controller)
        XCTAssertNil(controller.view.layer.animation(forKey: FWLanding.animationKey))
        // Core Animation keeps a transition under kCATransition whatever key it was added with.
        let fade = window.layer.animation(forKey: kCATransition) as? CATransition
        XCTAssertEqual(fade?.type, .fade, "the crossfade stays")
        XCTAssertEqual(fade?.duration ?? 0, FWLaunchTimeline.reducedLandingCrossfade, accuracy: 1e-9)
    }
}

final class FWLaunchFlightScheduleTests: XCTestCase {
    func testTheFlightStartsAtTheHoldPointOnlyWhenTheScreenIsReady() {
        XCTAssertEqual(FWLaunchSchedule.atZoomStart(screenReady: true), .startFlight)
        XCTAssertEqual(FWLaunchSchedule.atZoomStart(screenReady: false), .hold)
        // The hold ends as soon as the screen is ready, or once it has lasted too long.
        XCTAssertEqual(FWLaunchSchedule.whileHolding(screenReady: true, heldFor: 0.1), .resume)
        XCTAssertEqual(FWLaunchSchedule.whileHolding(screenReady: false, heldFor: 0.1), .hold)
        XCTAssertEqual(FWLaunchSchedule.whileHolding(screenReady: false, heldFor: FWLaunchTimeline.holdLimit), .resume)
    }

    func testATapStartsTheFlightAtOnceOrSpeedsItUp() {
        XCTAssertEqual(FWLaunchSchedule.onTap(flightRunning: false, finished: false), .startFlightSkipped)
        XCTAssertEqual(FWLaunchSchedule.onTap(flightRunning: true, finished: false), .speedUp)
        XCTAssertEqual(FWLaunchSchedule.onTap(flightRunning: false, finished: true), .ignore)
    }

    func testReducedMotionSkipsTheClipAndTheFlight() {
        let mode = FWLaunchSchedule.mode(
            alreadyPlayed: false, disabled: false, background: false, voiceOver: false,
            motionRestricted: true, clipAvailable: true
        )
        XCTAssertEqual(mode, .still)
    }
}

// MARK: - The sync dial

final class FWSyncDialTests: XCTestCase {
    func testDialStatesIncludingFailuresAndIdle() throws {
        let idle = FWShikiban.dialState(done: 0, failed: 0, total: 0)
        XCTAssertEqual(idle.phase, .idle)
        XCTAssertEqual(idle.lit, 0 ... 0)
        let syncing = FWShikiban.dialState(done: 9, failed: 0, total: 14)
        XCTAssertEqual(syncing.phase, .syncing)
        XCTAssertEqual(syncing.lit.upperBound, 9.0 / 14, accuracy: 1e-12)
        XCTAssertEqual(syncing.failed, 1 ... 1)
        XCTAssertEqual(FWShikiban.dialState(done: 14, failed: 0, total: 14).phase, .live)
        let partial = FWShikiban.dialState(done: 12, failed: 2, total: 14)
        XCTAssertEqual(partial.phase, .partial)
        XCTAssertEqual(partial.failed.lowerBound, 12.0 / 14, accuracy: 1e-12)
        XCTAssertTrue(partial.phase.isSettled)
        // Out-of-range input is clamped: answers never exceed the networks, failures never exceed the rest.
        let clamped = FWShikiban.dialState(done: 20, failed: 5, total: 14)
        XCTAssertEqual(clamped.done, 14)
        XCTAssertEqual(clamped.phase, .live)
        XCTAssertEqual(FWShikiban.dialState(done: 10, failed: 9, total: 14).failed.lowerBound, 10.0 / 14, accuracy: 1e-12)
    }

    func testSegmentsLeaveGapsAndCoverOnlyTheirArc() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let gap = tokens.dial.gapTurn
        let first = try XCTUnwrap(tokens.dialSegment(0, 0 ... 1))
        XCTAssertEqual(first.lowerBound, gap / 2, accuracy: 1e-12)
        XCTAssertEqual(first.upperBound, 1.0 / 8 - gap / 2, accuracy: 1e-12)
        XCTAssertNil(tokens.dialSegment(3, 0 ... 0.3))
        XCTAssertEqual(try XCTUnwrap(tokens.dialSegment(2, 0 ... 0.3)).upperBound, 0.3, accuracy: 1e-12)
        XCTAssertNil(tokens.dialSegment(0, 0 ... 0))
    }

    func testTheModelCountsOnlyWhatTheTrackerKnows() {
        var tracker = FWSyncTracker()
        XCTAssertEqual(FWDialModel.from(tracker: tracker), .settled)
        tracker.catalogSync(running: true)
        XCTAssertEqual(FWDialModel.from(tracker: tracker), .busy, "busy with nothing countable: the comet alone")
        XCTAssertEqual(FWDialModel.busy.state.phase, .idle)
        for index in 0 ..< 14 {
            tracker.connection("chain-\(index)", index < 9 ? .connected : .connecting)
        }
        let syncing = FWDialModel.from(tracker: tracker)
        XCTAssertEqual(syncing, .counts(done: 9, failed: 0, total: 14))
        XCTAssertEqual(syncing.countText, "9 / 14")
        for index in 9 ..< 12 {
            tracker.connection("chain-\(index)", .connected)
        }
        tracker.connection("chain-12", .unreachable)
        tracker.connection("chain-13", .unreachable)
        let partial = FWDialModel.from(tracker: tracker)
        XCTAssertEqual(partial, .counts(done: 12, failed: 2, total: 14))
        XCTAssertEqual(partial.state.phase, .partial)
        XCTAssertNil(partial.countText, "settled: no count")
    }

    func testTheCometRunsOnlyOnScreenWhileSyncingAndNeverUnderReducedMotion() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        window.isHidden = false
        defer { window.isHidden = true }
        let defaults = UserDefaults(suiteName: "FWSyncDialTests")!
        defaults.removePersistentDomain(forName: "FWSyncDialTests")
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
        let dial = FWSyncDialView(effects: effects)
        dial.frame = CGRect(x: 0, y: 0, width: 18, height: 18)
        dial.set(.counts(done: 3, failed: 0, total: 14), animated: false)
        XCTAssertFalse(dial.isCometRunning, "off screen")
        window.addSubview(dial)
        XCTAssertTrue(dial.isCometRunning)
        dial.set(.counts(done: 14, failed: 0, total: 14), animated: true)
        XCTAssertFalse(dial.isCometRunning, "settled: the comet stops")
        XCTAssertNotNil(dial.layer.sublayers?.first { $0.animation(forKey: FWSyncDialView.sealKey) != nil })

        let reduced = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init(reduceMotion: true) }
        let still = FWSyncDialView(effects: reduced)
        still.frame = dial.frame
        window.addSubview(still)
        still.set(.counts(done: 3, failed: 1, total: 14), animated: true)
        XCTAssertFalse(still.isCometRunning)
    }

    func testTheRowShowsTheCountOnlyWhileSyncingAndReusesExistingWords() {
        let row = FWSyncDialRow()
        row.locale = Locale(identifier: "en")
        row.set(.counts(done: 9, failed: 0, total: 14), animated: false)
        XCTAssertEqual(row.countLabel.text, "9 / 14")
        XCTAssertFalse(row.countLabel.isHidden)
        XCTAssertEqual(
            row.accessibilityLabel,
            R.string.localizable.networkStatusConnecting(preferredLanguages: ["en"]) + " 9 / 14"
        )
        row.set(.counts(done: 14, failed: 0, total: 14), animated: false)
        XCTAssertTrue(row.countLabel.isHidden)
        XCTAssertEqual(row.accessibilityLabel, R.string.localizable.networkStatusConnected(preferredLanguages: ["en"]))
    }
}

// MARK: - The seal

final class FWSealTests: XCTestCase {
    func testStagesMapToTheKitStrokesAndProgress() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        XCTAssertEqual(tokens.sealProgress(.ready), 0.26)
        XCTAssertEqual(tokens.sealProgress(.signed), 0.34)
        XCTAssertEqual(tokens.sealProgress(.sent), 0.375)
        XCTAssertEqual(tokens.sealProgress(.accepted), 0.41)
        XCTAssertEqual(tokens.sealStrokes(.ready), [.init(group: "ring", index: 0), .init(group: "ring", index: 1)])
        XCTAssertEqual(tokens.sealStrokes(.signed), [.init(group: "hexagram", index: 0)])
        XCTAssertEqual(tokens.sealStrokes(.sent), [.init(group: "hexagram", index: 1)])
        XCTAssertEqual(tokens.sealStrokes(.accepted), [.init(group: "hexagram", index: 2)])
        XCTAssertEqual(tokens.seal.stars, ["signed": 2, "sent": 4, "accepted": 0])
    }

    func testAmountsDrawOnlyTheStagesReached() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let accepted = tokens.sealProgress(.accepted)
        func amount(_ group: String, _ index: Int, q: Double, p: Double = 0.41, reveal: ClosedRange<Double> = 0.5 ... 0.6) -> Double {
            tokens.sealAmount(group: group, index: index, reveal: reveal, q: q, p: p)
        }
        XCTAssertEqual(amount("ring", 0, q: 0), 0)
        XCTAssertEqual(amount("ring", 1, q: 0.5), 0.5)
        XCTAssertEqual(amount("ring", 0, q: 1), 1)
        XCTAssertEqual(amount("hexagram", 0, q: 1), 0, "not signed yet")
        XCTAssertEqual(amount("hexagram", 0, q: 2), 1)
        XCTAssertEqual(amount("hexagram", 1, q: 2.5), 0.5)
        XCTAssertEqual(amount("hexagram", 2, q: 3), 0)
        XCTAssertEqual(amount("hexagram", 2, q: 4), 1)
        // The rest of the figure waits for acceptance, then follows the ignite from 0.41.
        XCTAssertEqual(amount("lattice", 0, q: 3.9, p: 1), 0)
        XCTAssertEqual(amount("lattice", 0, q: 4, p: accepted), 0)
        XCTAssertEqual(amount("lattice", 0, q: 4, p: 0.55), 0.5, accuracy: 1e-9)
        XCTAssertEqual(amount("lattice", 0, q: 4, p: 1), 1)
        // A corner star lands as its side closes.
        XCTAssertEqual(tokens.sealStarAmount(starIndex: 2, starReveal: 0.36, q: 1.5, p: accepted), 0)
        XCTAssertEqual(tokens.sealStarAmount(starIndex: 2, starReveal: 0.36, q: 2, p: accepted), 1)
        XCTAssertEqual(tokens.sealStarAmount(starIndex: 0, starReveal: 0.3, q: 3, p: accepted), 0)
        XCTAssertEqual(tokens.sealStarAmount(starIndex: 0, starReveal: 0.3, q: 4, p: accepted), 1)
        XCTAssertEqual(tokens.sealStarAmount(starIndex: 1, starReveal: 0.33, q: 3, p: 1), 0)
    }

    func testTheRecordKeepsTheStageReachedForTheSuccessScreen() {
        let record = FWSealRecord()
        XCTAssertNil(record.recent(now: 1))
        record.begin(now: 99)
        XCTAssertEqual(record.recent(now: 99.5), .idle, "a transfer that has drawn nothing yet")
        record.note(.ready, now: 100)
        XCTAssertEqual(record.recent(now: 101), .ready)
        record.note(.accepted, now: 102)
        XCTAssertEqual(record.recent(now: 103), .accepted)
        record.note(.signed, now: 104)
        XCTAssertEqual(record.recent(now: 105), .accepted, "a stage never goes back within one transfer")
        XCTAssertNil(record.recent(now: 104 + FWSealRecord.freshness + 1), "an old transfer is forgotten")
        record.begin(now: 200)
        record.note(.ready, now: 200)
        XCTAssertEqual(record.recent(now: 200), .ready, "a new transfer starts again")
        record.reset()
        XCTAssertNil(record.recent(now: 200))
    }

    func testTheSealViewShowsTheStagesWithoutMovingUnderReducedMotion() throws {
        let defaults = UserDefaults(suiteName: "FWSealTests")!
        defaults.removePersistentDomain(forName: "FWSealTests")
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init(reduceMotion: true) }
        let view = FWSolarGeometryView(effects: effects)
        view.frame = CGRect(x: 0, y: 0, width: 176, height: 176)
        view.layoutIfNeeded()
        view.advanceSeal(to: .signed)
        XCTAssertEqual(view.sealQ, 2, "reduced motion shows the strokes of the stages reached at once")
        XCTAssertFalse(view.isSealAnimating)
        XCTAssertEqual(view.strokeEnd(group: "ring", index: 0), 1)
        XCTAssertEqual(view.strokeEnd(group: "hexagram", index: 0), 1)
        XCTAssertEqual(view.strokeEnd(group: "hexagram", index: 1), 0)
        view.breakSeal()
        XCTAssertTrue(view.isSealBroken)
    }

    func testTheSealDrawsTowardsTheNextStageAndTheIgniteContinuesFromIt() throws {
        let defaults = UserDefaults(suiteName: "FWSealTests.full")!
        defaults.removePersistentDomain(forName: "FWSealTests.full")
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
        let view = FWSolarGeometryView(effects: effects)
        view.frame = CGRect(x: 0, y: 0, width: 176, height: 176)
        view.layoutIfNeeded()
        view.showSeal(stage: .ready)
        XCTAssertEqual(view.sealQ, 1)
        XCTAssertEqual(view.strokeEnd(group: "hexagram", index: 0), 0)
        view.advanceSeal(to: .accepted)
        XCTAssertTrue(view.isSealAnimating)
        view.stepSeal(byMs: 10_000)
        XCTAssertEqual(view.sealQ, 4)
        XCTAssertEqual(view.sealP, 1, accuracy: 1e-9)
        XCTAssertEqual(view.strokeEnd(group: "hexagram", index: 2), 1)
        XCTAssertEqual(view.strokeEnd(group: "lattice", index: 0), 1)
        XCTAssertFalse(view.isSealAnimating, "the display link stops when the figure rests")
    }
}

// MARK: - The loader and the hero's marks

final class FWLoaderAndMarksTests: XCTestCase {
    func testLoaderCometsAreAThirdOfATurnApartWithTheirTails() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let start = tokens.loaderComets(0)
        XCTAssertEqual(start.count, 3)
        for (index, comet) in start.enumerated() {
            XCTAssertEqual(comet.head, Double(index) / 3, accuracy: 1e-9)
            XCTAssertEqual(comet.head - comet.tail, tokens.loader.tailTurn, accuracy: 1e-9)
        }
        let quarter = tokens.loaderComets(tokens.loader.secondsPerTurn / 4)
        XCTAssertEqual(quarter[0].head, 0.25, accuracy: 1e-9)
        XCTAssertEqual(tokens.loaderComets(tokens.loader.secondsPerTurn)[0].head, 0, accuracy: 1e-9)
        // Every comet segment's window, and the same window one turn on, stays on the three-turn track.
        for comet in 0 ..< 3 {
            for segment in 0 ..< FWMirrorLoaderView.segmentCount {
                let window = FWMirrorLoaderView.window(comet: comet, segment: segment, tokens: tokens)
                XCTAssertGreaterThanOrEqual(window.start, 0)
                XCTAssertLessThanOrEqual(window.end + 1.0 / 3, 1 + 1e-9)
                XCTAssertLessThan(window.start, window.end)
            }
        }
    }

    func testTheRimRunsClockwiseFromTwelveThroughItsCusps() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let top = tokens.rimPoint(0)
        XCTAssertEqual(top.x, 0, accuracy: 1e-9)
        XCTAssertEqual(top.y, -1, accuracy: 1e-9)
        let right = tokens.rimPoint(0.25)
        XCTAssertEqual(right.x, 1, accuracy: 1e-9)
        XCTAssertEqual(right.y, 0, accuracy: 1e-9)
        let cusp = tokens.rimPoint(1.0 / 16)
        XCTAssertEqual(Double(hypot(cusp.x, cusp.y)), tokens.mirror.cusp, accuracy: 1e-5)
        XCTAssertGreaterThan(cusp.x, 0, "clockwise from 12 o'clock goes right")
    }

    func testTheLoaderRunsOnlyOnScreenAndFillsWithAKnownAmount() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        window.isHidden = false
        defer { window.isHidden = true }
        let defaults = UserDefaults(suiteName: "FWLoaderTests")!
        defaults.removePersistentDomain(forName: "FWLoaderTests")
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
        let loader = FWMirrorLoaderView(effects: effects)
        loader.frame = CGRect(x: 0, y: 0, width: 96, height: 96)
        loader.layoutIfNeeded()
        XCTAssertFalse(loader.isRunning)
        window.addSubview(loader)
        loader.layoutIfNeeded()
        XCTAssertTrue(loader.isRunning)
        loader.progress = 0.4
        XCTAssertFalse(loader.isRunning, "with a known amount the comets go")
        loader.removeFromSuperview()
        loader.progress = nil
        XCTAssertFalse(loader.isRunning)

        let reduced = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init(reduceMotion: true) }
        let still = FWMirrorLoaderView(effects: reduced)
        still.frame = loader.frame
        window.addSubview(still)
        still.layoutIfNeeded()
        XCTAssertFalse(still.isRunning, "reduced motion: the comets stand still")
    }

    func testTheHeroMarksFollowTheYamatoDivisions() throws {
        let bounds = CGRect(x: 0, y: 0, width: 370, height: 230)
        XCTAssertEqual(FWHeroMarksView.tickFractions[0], 1 - 1 / 2.0.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(FWHeroMarksView.tickFractions[2], 1 / 2.0.squareRoot(), accuracy: 1e-9)
        let brackets = FWHeroMarksView.bracketsPath(in: bounds).bounds
        XCTAssertEqual(brackets.minX, 9, accuracy: 0.01)
        XCTAssertEqual(brackets.maxX, 361, accuracy: 0.01)
        XCTAssertEqual(brackets.minY, 9, accuracy: 0.01)
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let lattice = tokens.asanohaPath(in: bounds, cell: 26)
        XCTAssertFalse(lattice.isEmpty)
        XCTAssertEqual(tokens.asanoha.height, 3.0.squareRoot(), accuracy: 1e-5)

        let defaults = UserDefaults(suiteName: "FWMarksTests")!
        defaults.removePersistentDomain(forName: "FWMarksTests")
        let reduced = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init(reduceMotion: true) }
        let marks = FWHeroMarksView(effects: reduced)
        marks.frame = bounds
        marks.layoutIfNeeded()
        XCTAssertTrue(marks.bandLattice.isHidden, "no band of light under reduced motion")
        XCTAssertFalse(marks.isBandMoving)
    }
}

// MARK: - The seal on the cross-chain, swap and staking confirms

/// A confirm screen whose loading is the app's full-page loader, wired exactly as the staking confirms are.
private final class LoaderConfirmScreen: UIViewController, LoadableViewProtocol, FWTransferSealShowing {
    func didReachTransferStage(_ stage: FWSealStage) {
        FWTransferSeal.reach(stage, in: view)
    }

    func didBreakTransfer() {
        FWTransferSeal.breakSeal(in: view)
    }
}

private final class SealSpy: FWTransferSealShowing {
    private(set) var calls: [String] = []

    func didReachTransferStage(_ stage: FWSealStage) {
        calls.append("stage:\(stage.name)")
    }

    func didBreakTransfer() {
        calls.append("break")
    }

    func didEndTransfer() {
        calls.append("end")
    }
}

private final class SwapOutputStub: PolkaswapSwapConfirmationViewOutput {
    func didLoad(view _: PolkaswapSwapConfirmationViewInput) {}
    func didTapBackButton() {}
    func didTapConfirmButton() {}
}

final class FWTransferSealFlowTests: XCTestCase {
    private struct Failure: Error {}

    private func window() throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.isHidden = false
        return window
    }

    private func spinRunLoop(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func testEachFlowsRealEventsLightOnlyTheStagesTheyKnow() {
        // The final press, authorised: every flow knows only this before the result.
        XCTAssertEqual(FWTransferEvent.authorised.stage, .ready)
        // Cross-chain: included and awaiting the bridge, or accepted but unconfirmed, both mean the network took it.
        XCTAssertEqual(FWTransferEvents.crossChain(.success(.awaitingBridge(extrinsicHash: "0x1"))), .accepted)
        XCTAssertEqual(FWTransferEvents.crossChain(.success(.unconfirmed(extrinsicHash: nil))), .accepted)
        XCTAssertEqual(FWTransferEvents.crossChain(.failure(Failure())), .definiteFailure)
        // Swap and staking (bond extra, unbond, rebond, redeem, payee, controller, payout): a hash, or a failure.
        XCTAssertEqual(FWTransferEvents.extrinsic(.success("0x2")), .accepted)
        XCTAssertEqual(FWTransferEvents.extrinsic(.failure(Failure())), .definiteFailure)
        // Payouts may come back as a list of hashes.
        XCTAssertEqual(FWTransferEvents.payouts(["0x3", "0x4"]), .accepted)
        XCTAssertEqual(FWTransferEvents.payouts([]), .outcomeUnknown)
        // Acceptance draws the rest at once: signed and sent are never reported on their own.
        XCTAssertEqual(FWTransferEvent.accepted.stage, .accepted)
        XCTAssertNil(FWTransferEvent.definiteFailure.stage)
        XCTAssertTrue(FWTransferEvent.definiteFailure.breaks)
        XCTAssertNil(FWTransferEvent.outcomeUnknown.stage)
        XCTAssertFalse(FWTransferEvent.outcomeUnknown.breaks)
    }

    func testReportingIsSynchronousAndANoOpForScreensWithoutASeal() {
        let spy = SealSpy()
        FWTransferEvents.report(.authorised, to: spy)
        FWTransferEvents.report(FWTransferEvents.extrinsic(.success("0x5")), to: spy)
        FWTransferEvents.report(.definiteFailure, to: spy)
        FWTransferEvents.report(.outcomeUnknown, to: spy)
        XCTAssertEqual(spy.calls, ["stage:ready", "stage:accepted", "break"], "each call lands before report returns")
        FWTransferEvents.report(.authorised, to: UIViewController())
        FWTransferEvents.report(.accepted, to: nil)
    }

    func testAButtonSpinnerScreenShowsTheSealOnInkAndFadesItWithoutHoldingTheResult() throws {
        let window = try window()
        defer { window.isHidden = true }
        let screen = PolkaswapSwapConfirmationViewController(output: SwapOutputStub(), localizationManager: nil)
        window.rootViewController = screen
        window.layoutIfNeeded()
        let framesBefore = screen.view.subviews.map(\.frame)

        screen.didStartLoading()
        FWTransferEvents.report(.authorised, to: screen)
        let overlay = try XCTUnwrap(FWTransferSeal.overlay(in: screen.view))
        XCTAssertFalse(overlay.isUserInteractionEnabled, "the seal never takes a touch")
        XCTAssertEqual(overlay.backgroundColor?.cgColor.alpha ?? 0, FWSealOverlayView.inkAlpha, accuracy: 0.001)
        let seal = try XCTUnwrap(FWTransferSeal.sealView(in: screen.view))
        XCTAssertEqual(seal.bounds.width, FWTransferSeal.side)
        XCTAssertEqual(Array(screen.view.subviews.dropLast().map(\.frame)), framesBefore, "nothing else moves")

        // The result: loading stops, the network accepted it. Both return at once; the presenter shows its success
        // in this same turn while the seal draws on and fades on the next.
        screen.didStopLoading()
        FWTransferEvents.report(.accepted, to: screen)
        XCTAssertNotNil(overlay.superview, "still there in this turn: nothing waited for it")
        spinRunLoop(0.6)
        XCTAssertNil(overlay.superview, "gone after its fade")
        XCTAssertNotNil(FWSealRecord.shared.recent(), "the stage reached is kept for a success screen")
    }

    func testADefiniteFailureBreaksTheSealBesideTheAppsError() throws {
        let window = try window()
        defer { window.isHidden = true }
        let screen = PolkaswapSwapConfirmationViewController(output: SwapOutputStub(), localizationManager: nil)
        window.rootViewController = screen
        window.layoutIfNeeded()
        FWTransferEvents.report(.authorised, to: screen)
        let seal = try XCTUnwrap(FWTransferSeal.sealView(in: screen.view))
        let overlay = try XCTUnwrap(FWTransferSeal.overlay(in: screen.view))
        screen.didStopLoading()
        FWTransferEvents.report(FWTransferEvents.extrinsic(.failure(Failure())), to: screen)
        XCTAssertTrue(seal.isSealBroken)
        XCTAssertTrue(overlay.isBreaking, "the break, not the plain fade")
        XCTAssertNil(FWSealRecord.shared.recent(), "a broken transfer leaves nothing for a success screen")
        spinRunLoop(1.5)
        XCTAssertNil(overlay.superview)
    }

    func testTheLoaderScreensPutTheSealInTheLoadersPlace() throws {
        let window = try window()
        defer { window.isHidden = true }
        let screen = LoaderConfirmScreen()
        window.rootViewController = screen
        window.layoutIfNeeded()
        screen.didStartLoading()
        FWTransferEvents.report(.authorised, to: screen)
        let loader = try XCTUnwrap(FWTransferSeal.loadingView(in: screen.view))
        let seal = try XCTUnwrap(FWTransferSeal.sealView(in: screen.view))
        XCTAssertTrue(seal.superview === loader)
        XCTAssertNil(FWTransferSeal.overlay(in: screen.view), "no ink overlay where the loader is")
        XCTAssertTrue(loader.subviews.filter { $0 !== seal }.allSatisfy(\.isHidden), "the comets give way to the seal")
        FWTransferEvents.report(.accepted, to: screen)
        screen.didStopLoading()
        XCTAssertNotNil(seal.superview, "it leaves with the loader's own fade")
    }

    func testReducedMotionShowsTheStageReachedStill() throws {
        let defaults = UserDefaults(suiteName: "FWTransferSealFlowTests")!
        defaults.removePersistentDomain(forName: "FWTransferSealFlowTests")
        let effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init(reduceMotion: true) }
        let seal = FWSolarGeometryView(effects: effects)
        seal.frame = CGRect(x: 0, y: 0, width: 176, height: 176)
        seal.layoutIfNeeded()
        seal.showSeal(stage: .idle)
        seal.advanceSeal(to: .ready)
        XCTAssertEqual(seal.sealQ, 1)
        XCTAssertFalse(seal.isSealAnimating)
        seal.advanceSeal(to: .accepted)
        XCTAssertEqual(seal.sealQ, 4)
        XCTAssertEqual(seal.sealP, 1)
        XCTAssertFalse(seal.isSealAnimating)
    }
}
