@testable import fearless
import UIKit
import XCTest

@MainActor
final class CovEAnimatedGeometryTests: XCTestCase {
    func testSolarSealAdvancesMonotonicallyIgnitesAndBreaks() throws {
        let fixture = try CovEEffectFixture()
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let geometry = try XCTUnwrap(FWSolarGeometry.bundled)
        let view = FWSolarGeometryView(effects: fixture.effects)
        let window = CovEHost.window(for: view, frame: CGRect(x: 30, y: 100, width: 240, height: 240))
        defer { CovEHost.close(window); FWSealRecord.shared.reset() }
        view.focus = CGPoint(x: 100, y: 110)
        view.radiusFraction = 0.8
        view.groupOpacity = ["ring": 0.5, "stars": 0.4]
        view.layoutIfNeeded()
        XCTAssertEqual(view.radius, 96)
        XCTAssertTrue(view.accessibilityElementsHidden)
        XCTAssertTrue(geometry.strokes.allSatisfy { $0.path(center: .zero, radius: 100) != nil })
        view.setProgress(-1)
        XCTAssertEqual(view.strokeEnd(group: "ring", index: 0), 0)
        view.setProgress(2)
        XCTAssertEqual(view.strokeEnd(group: "ring", index: 0), 1)
        XCTAssertNil(view.strokeEnd(group: "missing", index: 0))
        view.recordsSealStages = true
        FWSealRecord.shared.begin()
        view.showSeal(stage: .idle)
        XCTAssertEqual(view.sealQ, 0)
        XCTAssertTrue(CovELayers.all(in: view.layer).contains { $0.animation(forKey: FWSolarGeometryView.cometKey) != nil })
        for stage in [FWSealStage.ready, .signed, .sent, .accepted] {
            view.advanceSeal(to: stage)
            view.stepSeal(byMs: 5000)
            XCTAssertEqual(view.sealQ, stage.q, accuracy: 0.001)
            XCTAssertEqual(FWSealRecord.shared.stage, stage)
        }
        XCTAssertEqual(view.sealP, 1)
        XCTAssertEqual(view.alpha, CGFloat(tokens.seal.restStrength), accuracy: 0.001)
        XCTAssertFalse(view.isSealAnimating)
        view.advanceSeal(to: .ready)
        XCTAssertEqual(view.sealQ, FWSealStage.accepted.q, "Late earlier stages cannot move the seal backwards")
        view.setHeavenPlate(syncing: true, animated: false)
        XCTAssertEqual(view.turnBoost, 14)
        XCTAssertEqual(view.brightness, 1.5)
        view.setHeavenPlate(syncing: false, animated: true)
        XCTAssertTrue(CovEHost.spin(until: { view.turnBoost == 1 }, timeout: 4))
        XCTAssertEqual(view.brightness, 1)
        view.ignite(duration: 0.05, settleOpacity: 0.4, settleAfter: 0)
        XCTAssertTrue(view.isIgnited)
        XCTAssertTrue(CovELayers.all(in: view.layer).contains { $0.animation(forKey: "fw.ignite") != nil })
        view.breakSeal()
        XCTAssertTrue(view.isSealBroken)
        XCTAssertFalse(view.isSealAnimating)
        XCTAssertTrue(CovELayers.all(in: view.layer).contains { $0.animation(forKey: "fw.seal.break") != nil })
        view.breakSeal()
        view.stepSeal(byMs: 1000)
        XCTAssertEqual(view.sealQ, FWSealStage.accepted.q)
        view.setTurning(false)
        XCTAssertFalse(view.isTurning)
    }

    func testReducedSolarMotionSettlesImmediatelyAndMalformedStrokesHaveNoPath() throws {
        let fixture = try CovEEffectFixture(.reduced)
        let view = FWSolarGeometryView(effects: fixture.effects)
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 160)
        view.layoutIfNeeded()
        view.advanceSeal(to: .accepted)
        XCTAssertEqual(view.sealP, 1)
        XCTAssertEqual(view.sealQ, FWSealStage.accepted.q)
        XCTAssertFalse(view.isTurning)
        XCTAssertFalse(view.isSealAnimating)
        view.ignite(settleOpacity: 0.3)
        XCTAssertEqual(view.alpha, 0.3, accuracy: 0.001)
        view.breakSeal()
        let broken = try XCTUnwrap(CovELayers.all(in: view.layer).compactMap { $0.animation(forKey: "fw.seal.break") as? CAAnimationGroup }.first)
        let fall = try XCTUnwrap(broken.animations?.last as? CABasicAnimation)
        XCTAssertEqual(fall.toValue as? Double, 0)
        for type in ["circle", "line", "unknown"] {
            let data = Data("{\"type\":\"\(type)\",\"group\":\"test\",\"weight\":1,\"reveal\":[]}".utf8)
            let stroke = try JSONDecoder().decode(FWSolarGeometry.Stroke.self, from: data)
            XCTAssertNil(stroke.path(center: .zero, radius: 10))
            XCTAssertEqual(stroke.revealStart, 0)
            XCTAssertEqual(stroke.revealEnd, 1)
        }
        XCTAssertEqual(FWSolarGeometry.color("not-hex"), FWSunlit.color(0xFFC24A))
        let empty = FWSolarGeometryView(geometry: nil, effects: fixture.effects, tokens: nil)
        empty.showSeal(stage: .ready)
        empty.stepSeal(byMs: 100)
        XCTAssertFalse(empty.isSealAnimating)
        XCTAssertNil(empty.strokeEnd(group: "ring", index: 0))
    }

    func testFlightReplacesTiersFinishesOnceAndCancellationRestoresViews() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let root = UIViewController()
        let window = CovEHost.window(for: root)
        defer { CovEHost.close(window) }
        let first = UIView(frame: CGRect(x: 20, y: 100, width: 200, height: 80))
        first.alpha = 0.7
        let second = UIView(frame: CGRect(x: 20, y: 220, width: 200, height: 80))
        let cover = UIView(frame: root.view.bounds)
        [first, second, cover].forEach(root.view.addSubview)
        let feedback = CovEFeedbackRecorder()
        var events: [String] = []
        let flight = FWLaunchFlight(
            tokens: tokens,
            cover: cover,
            tiers: [FWFlightTier(view: first, tier: 0)],
            focus: CGPoint(x: 100, y: 180),
            feedback: feedback,
            onCleared: { events.append("clear") },
            onFinished: { events.append("finish") }
        )
        var current = first
        flight.currentScreen = { (ObjectIdentifier(current), { [FWFlightTier(view: current, tier: 1)] }) }
        flight.start()
        flight.advance(byMs: 400)
        XCTAssertFalse(first.transform.isIdentity)
        current = second
        flight.advance(byMs: 400)
        XCTAssertTrue(first.transform.isIdentity)
        XCTAssertEqual(first.alpha, 0.7, accuracy: 0.001)
        XCTAssertFalse(second.transform.isIdentity)
        flight.advance(byMs: 400)
        XCTAssertEqual(feedback.patterns, [.launchArrive])
        flight.skip()
        XCTAssertEqual(flight.rate, tokens.skipRate)
        flight.advance(byMs: tokens.flight.durationMs)
        flight.finish()
        XCTAssertTrue(flight.isFinished)
        XCTAssertTrue(second.transform.isIdentity)
        XCTAssertEqual(events, ["clear", "finish"])
        XCTAssertEqual(feedback.patterns, [.launchArrive])

        let cancelled = FWLaunchFlight(
            tokens: tokens,
            cover: cover,
            tiers: [FWFlightTier(view: first, tier: 0)],
            focus: .zero,
            feedback: feedback,
            onCleared: {},
            onFinished: {}
        )
        cancelled.start()
        cancelled.advance(byMs: 100)
        cancelled.cancel()
        XCTAssertTrue(cancelled.isFinished)
        XCTAssertTrue(first.transform.isIdentity)
        XCTAssertEqual(feedback.patterns, [.launchArrive], "Cancellation does not play arrival feedback")
    }

    func testTierPlanDeduplicatesNestedViewsAndLandingKeepsModelValues() throws {
        let tokens = try XCTUnwrap(FWShikiban.bundled)
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let child = UIView(frame: CGRect(x: 20, y: 30, width: 100, height: 40))
        parent.addSubview(child)
        parent.alpha = 0.8
        child.alpha = 0.6
        let tiers = [FWFlightTier(view: parent, tier: 0), FWFlightTier(view: child, tier: 2), FWFlightTier(view: child, tier: 2)]
        let plan = FWTierPlan(tiers: tiers, focus: CGPoint(x: 100, y: 100))
        XCTAssertEqual(plan.entries.count, 2)
        XCTAssertEqual(plan.entries[1].parent, 0)
        XCTAssertEqual(plan.transforms { $0 == 0 ? 2 : 4 }[1].a, 2)
        XCTAssertEqual(plan.alphas { $0 == 0 ? 0.5 : 0.25 }[1], 0.3, accuracy: 0.001)
        FWLanding.animate(tiers: tiers, focus: .zero, tokens: tokens)
        XCTAssertTrue(parent.transform.isIdentity)
        XCTAssertEqual(child.alpha, 0.6, accuracy: 0.001)
        let animation = try XCTUnwrap(child.layer.animation(forKey: FWLanding.animationKey) as? CAAnimationGroup)
        XCTAssertEqual(animation.animations?.count, 2)
        XCTAssertEqual(FWLanding.state(tier: 2, atMs: 10000, tokens: tokens).scale, 1)
        XCTAssertEqual(FWLanding.state(tier: 2, atMs: -100, tokens: tokens).opacity, 0)
        XCTAssertTrue(FWFlightTierFinder.tiers(in: nil).isEmpty)
        let root = UIViewController()
        root.view = parent
        XCTAssertTrue(FWFlightTierFinder.tiers(in: root).first?.view === parent)
        XCTAssertEqual(FWLaunchFlight.farthestCorner(from: .zero, in: CGRect(x: 0, y: 0, width: 3, height: 4)), 5)
    }
}

final class CovEEffectFixture {
    let suite = "CovE-effects-" + UUID().uuidString
    let defaults: UserDefaults
    let effects: FWEffects

    init(_ choice: FWEffectsChoice = .automatic) throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        effects = FWEffects(defaults: defaults, notificationCenter: NotificationCenter()) { .init() }
        effects.userChoice = choice
    }

    deinit { defaults.removePersistentDomain(forName: suite) }
}

enum CovELayers {
    static func all(in root: CALayer) -> [CALayer] {
        [root] + (root.sublayers ?? []).flatMap { all(in: $0) }
    }
}

final class CovEFeedbackRecorder: FWFeedbackPlaying, FWFeedbackSoundOutput, FWFeedbackHapticOutput {
    private(set) var patterns: [FWFeedbackPattern] = []
    private(set) var resources: [String] = []
    private(set) var preparations: [[String]] = []
    private(set) var hapticEvents: [[FWHapticPatterns.Event]] = []

    func play(_ pattern: FWFeedbackPattern) -> FWFeedbackOutcome {
        patterns.append(pattern)
        return FWFeedbackOutcome(sound: false, haptic: true)
    }

    func prepare(resources: [String]) {
        preparations.append(resources)
    }

    func play(resource: String) -> Bool {
        resources.append(resource); return true
    }

    func play(_ pattern: FWFeedbackPattern, events: [FWHapticPatterns.Event]) -> Bool {
        patterns.append(pattern)
        hapticEvents.append(events)
        return true
    }
}
