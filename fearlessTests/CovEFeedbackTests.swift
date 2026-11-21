@testable import fearless
import SoraUI
import UIKit
import XCTest

@MainActor
final class CovEFeedbackTests: XCTestCase {
    func testFeedbackSettingsPersistNotifyAndRouteEveryPattern() throws {
        let fixture = try CovEEffectFixture()
        let center = NotificationCenter()
        let settings = FWFeedbackSettings(defaults: fixture.defaults, notificationCenter: center)
        var changes = 0
        let observer = center.addObserver(forName: FWFeedbackSettings.didChange, object: nil, queue: .main) { _ in changes += 1 }
        defer { center.removeObserver(observer) }
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.hapticsEnabled)
        let output = CovEFeedbackRecorder()
        var foreground = true
        var launching = false
        let patterns = try XCTUnwrap(FWHapticPatterns.bundled())
        let feedback = FWFeedback(
            settings: settings,
            patterns: patterns,
            sound: output,
            haptics: output,
            isForeground: { foreground },
            isLaunching: { launching }
        )
        feedback.prepare()
        feedback.prepare()
        XCTAssertEqual(output.preparations, [["feedback-send", "feedback-receive"]])
        var reported: [String] = []
        let report = NotificationCenter.default.addObserver(forName: FWFeedback.didPlay, object: nil, queue: .main) { note in
            if let pattern = note.userInfo?["pattern"] as? String {
                reported.append(pattern)
            }
        }
        defer { NotificationCenter.default.removeObserver(report) }
        for pattern in FWFeedbackPattern.allCases {
            XCTAssertEqual(feedback.play(pattern), FWFeedbackOutcome(sound: pattern.soundResource != nil, haptic: true))
        }
        XCTAssertEqual(output.patterns, FWFeedbackPattern.allCases)
        XCTAssertEqual(output.resources, ["feedback-send", "feedback-receive"])
        XCTAssertEqual(output.hapticEvents.first, patterns.events(for: .send))
        XCTAssertEqual(reported, FWFeedbackPattern.allCases.map(\.rawValue))
        launching = true
        XCTAssertEqual(feedback.play(.send), FWFeedbackOutcome(haptic: true, skipped: ["launch"]))
        settings.soundEnabled = false
        settings.hapticsEnabled = false
        XCTAssertEqual(changes, 2)
        XCTAssertFalse(FWFeedbackSettings(defaults: fixture.defaults).soundEnabled)
        XCTAssertFalse(FWFeedbackSettings(defaults: fixture.defaults).hapticsEnabled)
        XCTAssertEqual(feedback.play(.receive), FWFeedbackOutcome(skipped: ["sound-off", "haptics-off"]))
        foreground = false
        XCTAssertEqual(feedback.play(.send), FWFeedbackOutcome(skipped: ["background"]))
        XCTAssertEqual(output.resources.count, 2)
        XCTAssertEqual(output.patterns.count, 6)
    }

    func testHapticDecodingAndGeneratorFallbackRetainTimingAndStrength() throws {
        let json = """
        {"formatVersion":1,"patterns":{"send":{"events":[
          {"type":"transient","time":0,"intensity":0.4,"sharpness":0.1},
          {"type":"continuous","time":0.2,"duration":0.3,"intensity":[0.2,0.8,0.3],"sharpness":0.4},
          {"type":"transient","time":0.6,"intensity":0.9,"sharpness":0.9}
        ]}}}
        """
        let patterns = try JSONDecoder().decode(FWHapticPatterns.self, from: Data(json.utf8))
        let events = patterns.events(for: .send)
        XCTAssertEqual(patterns.formatVersion, 1)
        XCTAssertEqual(events[0].intensity, [0.4])
        XCTAssertEqual(events[1].peakIntensity, 0.8)
        XCTAssertTrue(patterns.events(for: .receive).isEmpty)
        let steps = FWHapticPlayer.generatorSteps(for: .send, events: events)
        XCTAssertEqual(steps.map(\.time), [0, 0.5, 0.6])
        XCTAssertEqual(steps.map(\.style), [.soft, .medium, .rigid])
        XCTAssertEqual(steps.map(\.intensity), [0.4, 0.8, 0.9])
        XCTAssertEqual(FWHapticPlayer.generatorSteps(for: .commit, events: []).first?.intensity, 0.7)
        XCTAssertTrue(FWHapticPlayer.generatorSteps(for: .failure, events: []).isEmpty)
        XCTAssertEqual(FWHapticPatterns.Event(type: .transient, time: 0, intensity: [], sharpness: 0).peakIntensity, 0)
        let player = FWHapticPlayer(supportsCoreHaptics: false)
        XCTAssertTrue(player.play(.send, events: events))
        XCTAssertTrue(player.play(.failure, events: []))
        XCTAssertFalse(FWAmbientSoundPlayer().play(resource: "CovE-missing-sound"))
        XCTAssertNil(FWHapticPatterns.bundled(Bundle(for: Self.self)))
    }

    func testArrivalOnlyAnnouncesKnownVisibleIncreasesAndResetStartsFresh() {
        let detector = FWArrivalDetector()
        let key = FWArrivalDetector.key(walletId: "wallet", assetKey: "dot")
        XCTAssertEqual(key, "wallet|dot")
        detector.seed(key: key, amount: nil)
        XCTAssertFalse(detector.observe(key: key, amount: 5, hidden: false))
        detector.seed(key: key, amount: 100)
        XCTAssertTrue(detector.observe(key: key, amount: 6, hidden: false), "Seeding never replaces a known value")
        XCTAssertFalse(detector.observe(key: key, amount: nil, hidden: false))
        XCTAssertFalse(detector.observe(key: key, amount: 7, hidden: true))
        XCTAssertFalse(detector.observe(key: key, amount: 7, hidden: false))
        XCTAssertFalse(detector.observe(key: key, amount: 4, hidden: false))
        XCTAssertTrue(detector.observe(key: key, amount: 5, hidden: false))
        detector.reset()
        XCTAssertFalse(detector.observe(key: key, amount: 10, hidden: false))
        detector.seed(key: "other", amount: 1)
        XCTAssertTrue(detector.observe(key: "other", amount: 2, hidden: false))
    }

    func testArrivalAnnouncementThrottlesAndPublishesLocalizedBanner() throws {
        let output = CovEFeedbackRecorder()
        var enabled = false
        var now: TimeInterval = 10
        var banners: [ApplicationStatusAlertEvent] = []
        var symbols: [String] = []
        let observer = NotificationCenter.default.addObserver(forName: FWArrivalAnnouncer.didAnnounce, object: nil, queue: .main) { note in
            if let symbol = note.userInfo?["symbol"] as? String {
                symbols.append(symbol)
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let announcer = FWArrivalAnnouncer(feedback: output, canAnnounce: { enabled }, clock: { now }, presentBanner: { banners.append($0) })
        let locale = Locale(identifier: "en")
        XCTAssertFalse(announcer.announceNow(symbol: "DOT", locale: locale))
        enabled = true
        XCTAssertTrue(announcer.announceNow(symbol: "DOT", locale: locale))
        now = 12.99
        XCTAssertFalse(announcer.announceNow(symbol: "KSM", locale: locale))
        now = 13
        announcer.announce(symbol: "KSM", locale: locale)
        XCTAssertEqual(symbols, ["DOT", "KSM"])
        XCTAssertEqual(output.patterns, [.receive, .receive])
        let banner = try XCTUnwrap(banners.first as? FWTokensReceivedEvent)
        XCTAssertEqual(banner.titleText, "DOT received")
        XCTAssertEqual(banner.descriptionText, "")
        XCTAssertTrue(banner.autoDismissing)
        XCTAssertEqual(banner.backgroundColor, FWSunlit.Palette.gradientEnd)
        XCTAssertNotNil(banner.image)
        XCTAssertEqual(FWTokensReceivedEvent(symbol: "XOR", locale: Locale(identifier: "zz")).titleText, "XOR received")
        XCTAssertEqual(FWFeelText.string("CovE-missing-key", locale: locale), "CovE-missing-key")
    }
}
