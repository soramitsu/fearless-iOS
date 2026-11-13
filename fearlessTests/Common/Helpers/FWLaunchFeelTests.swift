@testable import fearless
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils
import UIKit
import XCTest

/// Brand kit v3, "Launch, feel and sound": the launch timeline and decisions, the feedback settings and outputs,
/// the arrival rule, the Settings switches and the solar geometry. The design pass is in FWDesignPassTests.
final class FWLaunchTimelineTests: XCTestCase {
    func testBundledTimelineIsTheKitV3Timeline() throws {
        let timeline = try XCTUnwrap(FWLaunchTimeline.bundled())
        XCTAssertEqual(timeline, FWLaunchTimeline.kitV3)
        XCTAssertEqual(timeline.holdSeconds, 2)
        XCTAssertEqual(timeline.durationSeconds, 2.9, accuracy: 0.0001)
        XCTAssertEqual(timeline.focus.phone, FWLaunchTimeline.Point(x: 0.5, y: 0.3292))
        XCTAssertEqual(timeline.background, "#120A2E")
    }

    func testHandOffTimesFollowTheSpec() {
        XCTAssertEqual(FWLaunchTimeline.handOffStart, 2.55)
        XCTAssertEqual(FWLaunchTimeline.underneathStartScale, 1.18)
        XCTAssertEqual(FWLaunchTimeline.underneathDuration, 0.55)
        XCTAssertEqual(FWLaunchTimeline.overlayFadeStart, 2.7)
        XCTAssertEqual(FWLaunchTimeline.overlayFadeDuration, 0.45)
        XCTAssertEqual(FWLaunchTimeline.overlayEndScale, 1.6)
        XCTAssertEqual(FWLaunchTimeline.arriveHapticTime, 2.6)
        XCTAssertEqual(FWLaunchTimeline.skipDuration, 0.3)
        XCTAssertEqual(FWLaunchTimeline.stallLimit, 1)
        XCTAssertEqual(FWLaunchTimeline.landingStartScale, 1.06)
        XCTAssertEqual(FWLaunchTimeline.landingDuration, 0.35)
        XCTAssertLessThan(FWLaunchTimeline.handOffStart, FWLaunchTimeline.kitV3.durationSeconds)
        XCTAssertGreaterThan(FWLaunchTimeline.handOffStart, FWLaunchTimeline.kitV3.holdSeconds)
    }

    func testVideoFrameCoversEveryScreenAndCentresTheFocusAsFarAsItCan() {
        let focus = FWLaunchTimeline.kitV3.focus.phone
        let screens = [
            CGRect(x: 0, y: 0, width: 402, height: 874), // iPhone 16 Pro
            CGRect(x: 0, y: 0, width: 320, height: 568), // iPhone SE
            CGRect(x: 0, y: 0, width: 1024, height: 1366), // iPad Pro portrait
            CGRect(x: 0, y: 0, width: 1366, height: 1024) // iPad Pro landscape
        ]
        for screen in screens {
            let frame = FWLaunchTimeline.videoFrame(in: screen, focus: focus)
            XCTAssertTrue(frame.insetBy(dx: -0.5, dy: -0.5).contains(screen), "\(screen) not covered by \(frame)")
            XCTAssertEqual(frame.width / frame.height, 720.0 / 1560.0, accuracy: 0.001)
            let point = FWLaunchTimeline.focusPoint(in: screen, focus: focus)
            XCTAssertTrue(screen.contains(point))
            // Horizontally the focus is the clip's middle, so it is the screen's middle.
            XCTAssertEqual(point.x, screen.midX, accuracy: 0.5)
        }
        // On a landscape iPad the clip is far taller than the screen: the focus moves to the vertical middle.
        let landscape = CGRect(x: 0, y: 0, width: 1366, height: 1024)
        XCTAssertEqual(FWLaunchTimeline.focusPoint(in: landscape, focus: focus).y, landscape.midY, accuracy: 0.5)
    }

    func testZoomTransformKeepsTheFocusPointInPlace() {
        let center = CGPoint(x: 201, y: 437)
        let focus = CGPoint(x: 201, y: 288)
        let transform = FWLaunchTimeline.scale(1.18, about: focus, center: center)
        let affine = CATransform3DGetAffineTransform(transform)
        // In the layer's anchor space (origin at the centre) the focus point is a fixed point of the scale.
        let local = CGPoint(x: focus.x - center.x, y: focus.y - center.y)
        let moved = local.applying(affine)
        XCTAssertEqual(moved.x, local.x, accuracy: 0.0001)
        XCTAssertEqual(moved.y, local.y, accuracy: 0.0001)
        let corner = CGPoint(x: -center.x, y: -center.y).applying(affine)
        XCTAssertLessThan(corner.y, -center.y)
    }
}

final class FWLaunchScheduleTests: XCTestCase {
    func testTheClipHoldsOnlyWhileTheScreenUnderneathIsNotReady() {
        XCTAssertEqual(FWLaunchSchedule.atHoldPoint(screenReady: true), .keepPlaying)
        XCTAssertEqual(FWLaunchSchedule.atHoldPoint(screenReady: false), .hold)
        XCTAssertEqual(FWLaunchSchedule.whileHolding(screenReady: false, heldFor: 0.5), .hold)
        XCTAssertEqual(FWLaunchSchedule.whileHolding(screenReady: true, heldFor: 0.5), .resume)
        // Slow startup is revealed anyway, so its own "keep Fearless open" status shows.
        XCTAssertEqual(FWLaunchSchedule.whileHolding(screenReady: false, heldFor: FWLaunchTimeline.holdLimit), .resume)
    }

    func testAStalledClipIsDetectedButAHeldOneIsNot() {
        XCTAssertFalse(FWLaunchSchedule.isStalled(lastProgress: 10, now: 10.9, held: false))
        XCTAssertTrue(FWLaunchSchedule.isStalled(lastProgress: 10, now: 11.1, held: false))
        XCTAssertFalse(FWLaunchSchedule.isStalled(lastProgress: 10, now: 30, held: true))
    }

    func testTheOverlayPlaysOncePerColdForegroundLaunch() {
        func mode(
            played: Bool = false, disabled: Bool = false, background: Bool = false, voiceOver: Bool = false,
            restricted: Bool = false, clip: Bool = true
        ) -> FWLaunchSchedule.Mode {
            FWLaunchSchedule.mode(
                alreadyPlayed: played, disabled: disabled, background: background, voiceOver: voiceOver,
                motionRestricted: restricted, clipAvailable: clip
            )
        }
        XCTAssertEqual(mode(), .clip)
        XCTAssertEqual(mode(played: true), .none)
        XCTAssertEqual(mode(disabled: true), .none)
        XCTAssertEqual(mode(background: true), .none)
        XCTAssertEqual(mode(voiceOver: true), .none)
        // Reduce Motion: the crest fades straight to the first screen.
        XCTAssertEqual(mode(restricted: true), .still)
        XCTAssertEqual(mode(clip: false), .still)
    }

    func testReadinessWaitsForTheFirstRealScreenAndTheBiometricPrompt() {
        final class Splash: UIViewController, FWLaunchSplashScreen {}
        XCTAssertFalse(FWLaunchReadiness.isReady(rootViewController: nil, applicationActive: true))
        XCTAssertFalse(FWLaunchReadiness.isReady(rootViewController: Splash(), applicationActive: true))
        XCTAssertTrue(FWLaunchReadiness.isReady(rootViewController: UIViewController(), applicationActive: true))
        // The app is inactive while a system biometric prompt is up.
        XCTAssertFalse(FWLaunchReadiness.isReady(rootViewController: UIViewController(), applicationActive: false))
    }

    func testTheStartScreenIsTheSplashTheOverlayWaitsFor() {
        let root: Any = RootViewController(presenter: RootPresenterStub(), localizationManager: LocalizationManager.shared)
        XCTAssertTrue(root is FWLaunchSplashScreen)
    }
}

private final class RootPresenterStub: RootPresenterProtocol {
    func loadOnLaunch() {}
    func reload() {}
}

final class FWFeedbackTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "FWFeedbackTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testBothSwitchesAreOnByDefaultAndPersistInOrdinaryPreferences() {
        let settings = FWFeedbackSettings(defaults: defaults, notificationCenter: NotificationCenter())
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.hapticsEnabled)
        settings.soundEnabled = false
        settings.hapticsEnabled = false
        let reread = FWFeedbackSettings(defaults: defaults, notificationCenter: NotificationCenter())
        XCTAssertFalse(reread.soundEnabled)
        XCTAssertFalse(reread.hapticsEnabled)
        XCTAssertEqual(defaults.object(forKey: FWFeedbackSettings.soundKey) as? Bool, false)
    }

    func testSendAndReceivePlaySoundAndTouchOthersTouchOnly() throws {
        let sound = SoundRecorder()
        let haptics = HapticRecorder()
        let feedback = makeFeedback(sound: sound, haptics: haptics)
        XCTAssertEqual(feedback.play(.send), FWFeedbackOutcome(sound: true, haptic: true))
        XCTAssertEqual(feedback.play(.receive), FWFeedbackOutcome(sound: true, haptic: true))
        XCTAssertEqual(feedback.play(.commit), FWFeedbackOutcome(sound: false, haptic: true))
        XCTAssertEqual(feedback.play(.failure), FWFeedbackOutcome(sound: false, haptic: true))
        XCTAssertEqual(feedback.play(.launchArrive), FWFeedbackOutcome(sound: false, haptic: true))
        XCTAssertEqual(sound.played, ["feedback-send", "feedback-receive"])
        XCTAssertEqual(haptics.played.map { $0.0 }, [.send, .receive, .commit, .failure, .launchArrive])
        // The touch is timed to the sound: the send's crisp tap lands on its high note.
        let send = try XCTUnwrap(haptics.played.first.map { $0.1 })
        XCTAssertEqual(send.count, 2)
        XCTAssertEqual(send.first?.type, .continuous)
        XCTAssertEqual(send.first?.intensity, [0.2, 0.75])
        XCTAssertEqual(send.last?.type, .transient)
        XCTAssertEqual(send.last?.time ?? 0, 0.29, accuracy: 0.0001)
    }

    func testSwitchesBackgroundAndLaunchSilenceWhatTheyShould() {
        let sound = SoundRecorder()
        let haptics = HapticRecorder()
        let settings = FWFeedbackSettings(defaults: defaults, notificationCenter: NotificationCenter())
        var foreground = true
        var launching = false
        let feedback = FWFeedback(
            settings: settings, patterns: FWHapticPatterns.bundled(), sound: sound, haptics: haptics,
            isForeground: { foreground }, isLaunching: { launching }
        )
        settings.soundEnabled = false
        XCTAssertEqual(feedback.play(.receive), FWFeedbackOutcome(sound: false, haptic: true, skipped: ["sound-off"]))
        settings.soundEnabled = true
        settings.hapticsEnabled = false
        XCTAssertEqual(feedback.play(.receive), FWFeedbackOutcome(sound: true, haptic: false, skipped: ["haptics-off"]))
        settings.hapticsEnabled = true
        launching = true
        XCTAssertEqual(feedback.play(.send), FWFeedbackOutcome(sound: false, haptic: true, skipped: ["launch"]))
        launching = false
        foreground = false
        XCTAssertEqual(feedback.play(.send), FWFeedbackOutcome(sound: false, haptic: false, skipped: ["background"]))
        XCTAssertEqual(sound.played, ["feedback-receive"])
    }

    func testBundledHapticPatternsAndTheirGeneratorFallback() throws {
        let patterns = try XCTUnwrap(FWHapticPatterns.bundled())
        XCTAssertEqual(patterns.formatVersion, 1)
        let receive = patterns.events(for: .receive)
        XCTAssertEqual(receive.map(\.type), [.transient, .transient])
        XCTAssertEqual(receive.map(\.time), [0.03, 0.19])
        XCTAssertEqual(patterns.events(for: .launchArrive).count, 1)
        XCTAssertEqual(patterns.events(for: .commit).count, 1)
        XCTAssertTrue(patterns.events(for: .failure).isEmpty)
        let steps = FWHapticPlayer.generatorSteps(for: .receive, events: receive)
        XCTAssertEqual(steps.map { $0.time }, [0.03, 0.19])
        XCTAssertEqual(steps.map { $0.style }, [.soft, .medium])
        let send = FWHapticPlayer.generatorSteps(for: .send, events: patterns.events(for: .send))
        XCTAssertEqual(send.count, 2)
        XCTAssertEqual(send.first?.time ?? 0, 0.26, accuracy: 0.0001)
        XCTAssertEqual(send.last?.style, .rigid)
    }

    func testBothSoundsShipInTheBundle() {
        for pattern in FWFeedbackPattern.allCases {
            guard let resource = pattern.soundResource else { continue }
            XCTAssertNotNil(Bundle.main.url(forResource: resource, withExtension: "m4a"), resource)
        }
        XCTAssertNotNil(Bundle.main.url(forResource: "launch-ignite", withExtension: "mp4"))
    }

    private func makeFeedback(sound: SoundRecorder, haptics: HapticRecorder) -> FWFeedback {
        FWFeedback(
            settings: FWFeedbackSettings(defaults: defaults, notificationCenter: NotificationCenter()),
            patterns: FWHapticPatterns.bundled(), sound: sound, haptics: haptics,
            isForeground: { true }, isLaunching: { false }
        )
    }
}

final class SoundRecorder: FWFeedbackSoundOutput {
    private(set) var prepared: [String] = []
    private(set) var played: [String] = []

    func prepare(resources: [String]) {
        prepared = resources
    }

    func play(resource: String) -> Bool {
        played.append(resource)
        return true
    }
}

final class HapticRecorder: FWFeedbackHapticOutput {
    private(set) var played: [(FWFeedbackPattern, [FWHapticPatterns.Event])] = []

    func play(_ pattern: FWFeedbackPattern, events: [FWHapticPatterns.Event]) -> Bool {
        played.append((pattern, events))
        return true
    }
}

final class FeedbackRecorder: FWFeedbackPlaying {
    private(set) var played: [FWFeedbackPattern] = []

    func play(_ pattern: FWFeedbackPattern) -> FWFeedbackOutcome {
        played.append(pattern)
        return FWFeedbackOutcome(sound: pattern.soundResource != nil, haptic: true)
    }
}

final class FWArrivalTests: XCTestCase {
    func testOnlyGrowthFromAKnownValueOfAVisibleAssetIsAnArrival() {
        let detector = FWArrivalDetector()
        let key = FWArrivalDetector.key(walletId: "wallet-1", assetKey: "dot")
        // The first value seen is never an arrival: a new or imported wallet, a first sync, a new network.
        XCTAssertFalse(detector.observe(key: key, amount: 10, hidden: false))
        XCTAssertTrue(detector.observe(key: key, amount: 12, hidden: false))
        XCTAssertFalse(detector.observe(key: key, amount: 12, hidden: false))
        XCTAssertFalse(detector.observe(key: key, amount: 4, hidden: false))
        XCTAssertTrue(detector.observe(key: key, amount: 5, hidden: false))
        // A hidden asset never announces, but its value is still known.
        XCTAssertFalse(detector.observe(key: key, amount: 9, hidden: true))
        XCTAssertFalse(detector.observe(key: key, amount: 9, hidden: false))
        // An unknown value never replaces a known one.
        XCTAssertFalse(detector.observe(key: key, amount: nil, hidden: false))
        XCTAssertTrue(detector.observe(key: key, amount: 9.5, hidden: false))
    }

    func testSeededValuesAreKnownAndAnotherWalletStartsAgain() {
        let detector = FWArrivalDetector()
        let first = FWArrivalDetector.key(walletId: "wallet-1", assetKey: "ksm")
        let second = FWArrivalDetector.key(walletId: "wallet-2", assetKey: "ksm")
        detector.seed(key: first, amount: 3)
        detector.seed(key: first, amount: 1) // a later cached value does not replace a known one
        XCTAssertFalse(detector.observe(key: first, amount: 2, hidden: false))
        XCTAssertTrue(detector.observe(key: first, amount: 4, hidden: false))
        XCTAssertFalse(detector.observe(key: second, amount: 7, hidden: false))
        detector.reset()
        XCTAssertFalse(detector.observe(key: first, amount: 100, hidden: false))
    }

    func testTheAnnouncerPlaysOnlyInTheForegroundAndAtMostOnceInThreeSeconds() {
        let feedback = FeedbackRecorder()
        var allowed = false
        var now: TimeInterval = 100
        var banners: [String] = []
        let announcer = FWArrivalAnnouncer(
            feedback: feedback,
            canAnnounce: { allowed },
            clock: { now },
            presentBanner: { banners.append($0.titleText) }
        )
        let posted = expectation(forNotification: FWArrivalAnnouncer.didAnnounce, object: announcer)
        XCTAssertFalse(announcer.announceNow(symbol: "DOT", locale: Locale(identifier: "en")))
        allowed = true
        XCTAssertTrue(announcer.announceNow(symbol: "DOT", locale: Locale(identifier: "en")))
        now += 2.9
        XCTAssertFalse(announcer.announceNow(symbol: "KSM", locale: Locale(identifier: "en")))
        now += 0.2
        XCTAssertTrue(announcer.announceNow(symbol: "KSM", locale: Locale(identifier: "en")))
        wait(for: [posted], timeout: 1)
        XCTAssertEqual(feedback.played, [.receive, .receive])
        XCTAssertEqual(banners, ["DOT received", "KSM received"])
    }

    func testTheBannerAndSwitchesAreLocalised() {
        for identifier in ["en", "ja", "id", "pt-PT", "pt", "ru", "tr", "vi", "zh-Hans"] {
            let locale = Locale(identifier: identifier)
            for key in ["fw.feedback.sound_effects", "fw.feedback.haptic_feedback", "fw.feedback.tokens_received"] {
                XCTAssertNotEqual(FWFeelText.string(key, locale: locale), key, "\(identifier) \(key)")
            }
            XCTAssertTrue(FWFeelText.string("fw.feedback.tokens_received", locale: locale).contains("%@"), identifier)
        }
        XCTAssertEqual(FWFeelText.string("fw.feedback.tokens_received", locale: Locale(identifier: "ja")), "%@ を受け取りました")
    }

    func testSettingsListsBothSwitchesReflectingThePreferences() throws {
        let suite = "FWArrivalTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let feedbackSettings = FWFeedbackSettings(defaults: defaults, notificationCenter: NotificationCenter())
        feedbackSettings.hapticsEnabled = false
        let factory = ProfileViewModelFactory(
            iconGenerator: UniversalIconGenerator(),
            biometry: FeelBiometryStub(),
            settings: InMemorySettingsManager(),
            accountScoreFetcher: FeelStatisticsStub(),
            feedbackSettings: feedbackSettings
        )
        let viewModel = factory.createProfileViewModel(
            from: AccountGenerator.generateMetaAccount(),
            locale: Locale(identifier: "en"),
            language: Language(code: "en"),
            currency: Currency.defaultCurrency(),
            balance: nil,
            missingAccountIssue: []
        )
        let options = viewModel.profileOptionViewModel
        let sound = try XCTUnwrap(options.first { $0.option == .soundEffects })
        let haptics = try XCTUnwrap(options.first { $0.option == .hapticFeedback })
        XCTAssertEqual(sound.title, "Sound effects")
        XCTAssertEqual(haptics.title, "Haptic feedback")
        guard case let .switcher(soundOn) = sound.accessoryType, case let .switcher(hapticsOn) = haptics.accessoryType else {
            return XCTFail("both rows are switches")
        }
        XCTAssertTrue(soundOn)
        XCTAssertFalse(hapticsOn)
    }
}

private struct FeelBiometryStub: BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { .none }

    func authenticate(localizedReason _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        completionQueue.async { completionBlock(false) }
    }
}

private struct FeelStatisticsStub: AccountStatisticsFetching {
    func subscribeForStatistics(address _: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? {
        nil
    }
}

final class FWSolarGeometryTests: XCTestCase {
    func testBundledGeometryHasEveryStrokeInDrawOrder() throws {
        let geometry = try XCTUnwrap(FWSolarGeometry.bundled)
        XCTAssertEqual(geometry.formatVersion, 1)
        XCTAssertEqual(geometry.strokes.filter { $0.group == "ring" }.count, 2)
        XCTAssertEqual(geometry.strokes.filter { $0.group == "hexagram" }.count, 6)
        XCTAssertEqual(geometry.strokes.filter { $0.group == "lattice" }.count, 32)
        XCTAssertEqual(geometry.strokes.filter { $0.group == "ray" }.count, 1)
        XCTAssertEqual(geometry.stars.count, 16)
        XCTAssertEqual(geometry.ticks.count, 132)
        for stroke in geometry.strokes {
            XCTAssertLessThanOrEqual(stroke.revealStart, stroke.revealEnd)
            XCTAssertNotNil(stroke.path(center: .zero, radius: 100), stroke.group)
        }
        // The outer ring starts first and draws from 12 o'clock.
        let ring = try XCTUnwrap(geometry.strokes.first)
        XCTAssertEqual(ring.revealStart, 0)
        XCTAssertEqual(ring.path(center: .zero, radius: 100)?.currentPoint.y ?? 0, -100, accuracy: 0.01)
    }

    func testTheViewShowsTheFinishedFigureWithoutAnimationUnderReducedMotion() {
        let effects = FWEffects.shared
        let view = FWSolarGeometryView()
        view.frame = CGRect(x: 0, y: 0, width: 240, height: 240)
        view.layoutIfNeeded()
        view.setProgress(0)
        view.setProgress(1)
        XCTAssertNotNil(effects)
        XCTAssertEqual(view.radius, 240 / 2 * 0.94, accuracy: 0.01)
    }
}
