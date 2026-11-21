import AVFoundation
import CoreHaptics
import os.log
import UIKit

/// Sound and touch for sending and receiving tokens (brand kit v3, "Launch, feel and sound", part 2).
///
/// - Sound follows the device: the `.ambient` category lets the silent switch mute it and mixes with other audio. The
///   session is touched only when a sound actually plays, and the previous category comes back afterwards.
/// - Touch plays the kit's Core Haptics patterns (`feedback-haptics.json`), timed to the sounds, and falls back to the
///   nearest `UIFeedbackGenerator` where Core Haptics is missing. A failure always uses the system's error pattern.
/// - Both follow the user's two switches in Settings ("Sound effects", "Haptic feedback"), on by default.
/// - Nothing plays while the app is not in the foreground, and a launch never makes a sound.
enum FWFeedbackPattern: String, CaseIterable {
    /// The transfer was accepted by the network.
    case send
    /// Tokens arrived in the selected wallet.
    case receive
    /// The launch dive lands in the wallet. Touch only.
    case launchArrive
    /// The final Send / Confirm control, a copied receive address, a round action. Touch only.
    case commit
    /// The transfer failed or was rejected. Touch only, the system's error pattern.
    case failure

    /// The bundled sound resource, for the two patterns that have one.
    var soundResource: String? {
        switch self {
        case .send: return "feedback-send"
        case .receive: return "feedback-receive"
        case .launchArrive, .commit, .failure: return nil
        }
    }
}

/// What a success screen celebrates: an accepted token transfer plays the send sound and touch and ignites the solar
/// geometry around the screen's mark.
enum FWTransferCelebration: Equatable {
    case send
}

/// The user's switches for sound effects and haptic feedback. Ordinary preferences, never key storage.
final class FWFeedbackSettings {
    static let shared = FWFeedbackSettings()
    static let soundKey = "fw.feedback.sound.v1"
    static let hapticsKey = "fw.feedback.haptics.v1"
    static let didChange = Notification.Name("FWFeedbackSettingsDidChange")

    private let defaults: UserDefaults
    let notificationCenter: NotificationCenter

    init(defaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    /// "Sound effects": on unless the user turned it off.
    var soundEnabled: Bool {
        get { defaults.object(forKey: Self.soundKey) as? Bool ?? true }
        set { store(newValue, forKey: Self.soundKey) }
    }

    /// "Haptic feedback": on unless the user turned it off.
    var hapticsEnabled: Bool {
        get { defaults.object(forKey: Self.hapticsKey) as? Bool ?? true }
        set { store(newValue, forKey: Self.hapticsKey) }
    }

    private func store(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
        notificationCenter.post(name: Self.didChange, object: self)
    }
}

/// The kit's haptic patterns (`tokens/haptics.json`, kit v3). Times are seconds from the start of the matching sound;
/// intensity and sharpness are Core Haptics' 0–1 scales.
struct FWHapticPatterns: Decodable, Equatable {
    struct Event: Decodable, Equatable {
        enum Kind: String, Decodable {
            case transient, continuous
        }

        let type: Kind
        let time: Double
        let duration: Double?
        /// One value, or the start and end of a ramp for a continuous event.
        let intensity: [Double]
        let sharpness: Double

        private enum CodingKeys: String, CodingKey {
            case type, time, duration, intensity, sharpness
        }

        init(type: Kind, time: Double, duration: Double? = nil, intensity: [Double], sharpness: Double) {
            self.type = type
            self.time = time
            self.duration = duration
            self.intensity = intensity
            self.sharpness = sharpness
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(Kind.self, forKey: .type)
            time = try container.decode(Double.self, forKey: .time)
            duration = try container.decodeIfPresent(Double.self, forKey: .duration)
            sharpness = try container.decode(Double.self, forKey: .sharpness)
            if let ramp = try? container.decode([Double].self, forKey: .intensity), !ramp.isEmpty {
                intensity = ramp
            } else {
                intensity = [try container.decode(Double.self, forKey: .intensity)]
            }
        }

        /// The strongest point of the event.
        var peakIntensity: Double { intensity.max() ?? 0 }
    }

    struct Pattern: Decodable, Equatable {
        let sound: String?
        let events: [Event]?
    }

    let formatVersion: Int
    let patterns: [String: Pattern]

    func events(for pattern: FWFeedbackPattern) -> [Event] {
        patterns[pattern.rawValue]?.events ?? []
    }

    static func bundled(_ bundle: Bundle = .main) -> FWHapticPatterns? {
        guard let url = bundle.url(forResource: "feedback-haptics", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(FWHapticPatterns.self, from: data)
    }
}

/// Plays one feedback pattern. Injected so tests and debug seams can observe what would have played.
protocol FWFeedbackPlaying: AnyObject {
    @discardableResult
    func play(_ pattern: FWFeedbackPattern) -> FWFeedbackOutcome
}

/// What a request actually did.
struct FWFeedbackOutcome: Equatable {
    var sound = false
    var haptic = false
    /// Why nothing (or only part) played, for the log: "background", "sound-off", "haptics-off", "launch".
    var skipped: [String] = []
}

protocol FWFeedbackSoundOutput: AnyObject {
    func prepare(resources: [String])
    func play(resource: String) -> Bool
}

protocol FWFeedbackHapticOutput: AnyObject {
    func play(_ pattern: FWFeedbackPattern, events: [FWHapticPatterns.Event]) -> Bool
}

final class FWFeedback: FWFeedbackPlaying {
    static let shared = FWFeedback()
    /// Posted on the main queue after every request, with the pattern's raw value and the outcome, so a debug
    /// recording can prove which calls were made on a simulator that has neither speaker nor Taptic Engine.
    static let didPlay = Notification.Name("FWFeedbackDidPlay")

    let settings: FWFeedbackSettings
    private let patterns: FWHapticPatterns?
    private let sound: FWFeedbackSoundOutput
    private let haptics: FWFeedbackHapticOutput
    private let isForeground: () -> Bool
    private let isLaunching: () -> Bool
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "jp.co.soramitsu.fearlesswallet", category: "feedback")
    private var prepared = false

    init(
        settings: FWFeedbackSettings = .shared,
        patterns: FWHapticPatterns? = .bundled(),
        sound: FWFeedbackSoundOutput = FWAmbientSoundPlayer(),
        haptics: FWFeedbackHapticOutput = FWHapticPlayer(),
        isForeground: @escaping () -> Bool = { UIApplication.shared.applicationState == .active },
        isLaunching: @escaping () -> Bool = { FWLaunchIgnite.isShowing }
    ) {
        self.settings = settings
        self.patterns = patterns
        self.sound = sound
        self.haptics = haptics
        self.isForeground = isForeground
        self.isLaunching = isLaunching
    }

    /// Decodes the two sounds ahead of their first use, off the main thread, so the first send does not hitch.
    func prepare() {
        guard !prepared else { return }
        prepared = true
        sound.prepare(resources: FWFeedbackPattern.allCases.compactMap(\.soundResource))
    }

    @discardableResult
    func play(_ pattern: FWFeedbackPattern) -> FWFeedbackOutcome {
        var outcome = FWFeedbackOutcome()
        if !isForeground() {
            outcome.skipped.append("background")
        } else {
            if let resource = pattern.soundResource {
                if !settings.soundEnabled {
                    outcome.skipped.append("sound-off")
                } else if isLaunching() {
                    outcome.skipped.append("launch")
                } else {
                    outcome.sound = sound.play(resource: resource)
                }
            }
            if settings.hapticsEnabled {
                outcome.haptic = haptics.play(pattern, events: patterns?.events(for: pattern) ?? [])
            } else {
                outcome.skipped.append("haptics-off")
            }
        }
        os_log(
            "FW_FEEDBACK pattern=%{public}@ sound=%{public}ld haptic=%{public}ld skipped=%{public}@",
            log: log,
            type: .default,
            pattern.rawValue,
            outcome.sound ? 1 : 0,
            outcome.haptic ? 1 : 0,
            outcome.skipped.joined(separator: ",")
        )
        let post = { [outcome] in
            NotificationCenter.default.post(
                name: Self.didPlay,
                object: self,
                userInfo: ["pattern": pattern.rawValue, "sound": outcome.sound, "haptic": outcome.haptic]
            )
        }
        if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
        return outcome
    }
}

/// Plays the two short sounds with `AVAudioPlayer` under the `.ambient` category. Everything that touches the audio
/// session or starts a player runs on its own serial queue: the first activation can take seconds on a busy device,
/// and the main thread must never wait for it.
final class FWAmbientSoundPlayer: NSObject, FWFeedbackSoundOutput, AVAudioPlayerDelegate {
    private struct AudioCategory {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
    }

    private let bundle: Bundle
    private let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.feedback.sound", qos: .userInitiated)
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "jp.co.soramitsu.fearlesswallet", category: "feedback")
    // Touched on `queue` only.
    private var decoded: [String: Data] = [:]
    private var players: [AVAudioPlayer] = []
    private var previousCategory: AudioCategory?

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// Reads the files ahead of their first use. Creating players and touching the audio session wait for the first
    /// play, so preparing never interrupts the user's music.
    func prepare(resources: [String]) {
        queue.async { [weak self] in
            for resource in resources {
                _ = self?.data(for: resource)
            }
        }
    }

    /// Queues the sound; true when the sound exists. The queue reports whether the player actually started.
    func play(resource: String) -> Bool {
        guard bundle.url(forResource: resource, withExtension: "m4a") != nil else { return false }
        queue.async { [weak self] in
            self?.start(resource)
        }
        return true
    }

    private func data(for resource: String) -> Data? {
        if let data = decoded[resource] { return data }
        guard let url = bundle.url(forResource: resource, withExtension: "m4a"),
              let data = try? Data(contentsOf: url) else { return nil }
        decoded[resource] = data
        return data
    }

    private func start(_ resource: String) {
        guard let data = data(for: resource), let player = try? AVAudioPlayer(data: data) else { return }
        useAmbientAudio()
        player.delegate = self
        players.append(player)
        let started = player.play()
        os_log("FW_FEEDBACK_SOUND resource=%{public}@ started=%{public}ld", log: log, type: .default, resource, started ? 1 : 0)
        if !started { finish(player) }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        queue.async { [weak self] in self?.finish(player) }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error _: Error?) {
        queue.async { [weak self] in self?.finish(player) }
    }

    private func finish(_ player: AVAudioPlayer) {
        players.removeAll { $0 === player }
        guard players.isEmpty, let previous = previousCategory else { return }
        previousCategory = nil
        try? AVAudioSession.sharedInstance().setCategory(previous.category, mode: previous.mode, options: previous.options)
    }

    /// The silent switch mutes the sound and other apps' audio keeps playing.
    private func useAmbientAudio() {
        let session = AVAudioSession.sharedInstance()
        guard session.category != .ambient else { return }
        if previousCategory == nil {
            previousCategory = AudioCategory(category: session.category, mode: session.mode, options: session.categoryOptions)
        }
        try? session.setCategory(.ambient, mode: .default, options: [])
    }
}

/// Core Haptics where the hardware supports it, else the nearest `UIFeedbackGenerator`.
final class FWHapticPlayer: FWFeedbackHapticOutput {
    private let supportsCoreHaptics: Bool
    private var engine: CHHapticEngine?

    init(supportsCoreHaptics: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics) {
        self.supportsCoreHaptics = supportsCoreHaptics
    }

    func play(_ pattern: FWFeedbackPattern, events: [FWHapticPatterns.Event]) -> Bool {
        if pattern == .failure {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return true
        }
        if supportsCoreHaptics, !events.isEmpty, playCoreHaptics(events) {
            return true
        }
        playGenerators(Self.generatorSteps(for: pattern, events: events))
        return true
    }

    /// The fallback taps: one per transient event at its time, one for a continuous event at its peak.
    static func generatorSteps(
        for pattern: FWFeedbackPattern,
        events: [FWHapticPatterns.Event]
    ) -> [(time: Double, style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat)] {
        guard !events.isEmpty else {
            return pattern == .failure ? [] : [(0, .medium, 0.7)]
        }
        return events.map { event in
            let time = event.type == .continuous ? event.time + (event.duration ?? 0) : event.time
            let style: UIImpactFeedbackGenerator.FeedbackStyle
            switch event.sharpness {
            case ..<0.3: style = .soft
            case ..<0.6: style = .medium
            default: style = .rigid
            }
            return (time, style, CGFloat(event.peakIntensity))
        }
    }

    private func playGenerators(_ steps: [(time: Double, style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat)]) {
        for step in steps {
            let generator = UIImpactFeedbackGenerator(style: step.style)
            generator.prepare()
            if step.time <= 0.001 {
                generator.impactOccurred(intensity: step.intensity)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + step.time) {
                    generator.impactOccurred(intensity: step.intensity)
                }
            }
        }
    }

    private func playCoreHaptics(_ events: [FWHapticPatterns.Event]) -> Bool {
        do {
            let engine = try currentEngine()
            let pattern = try CHHapticPattern(
                events: events.map(Self.hapticEvent),
                parameterCurves: events.compactMap(Self.intensityRamp)
            )
            // The engine starts asynchronously, so the main thread never waits for the Taptic Engine.
            engine.start { error in
                guard error == nil, let player = try? engine.makePlayer(with: pattern) else { return }
                try? player.start(atTime: CHHapticTimeImmediate)
            }
            return true
        } catch {
            engine = nil
            return false
        }
    }

    private func currentEngine() throws -> CHHapticEngine {
        if let engine { return engine }
        let engine = try CHHapticEngine()
        // Haptics only: the engine never touches the audio session.
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak self] in self?.engine = nil }
        engine.stoppedHandler = { [weak self] _ in self?.engine = nil }
        self.engine = engine
        return engine
    }

    private static func hapticEvent(_ event: FWHapticPatterns.Event) -> CHHapticEvent {
        let parameters = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(event.peakIntensity)),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(event.sharpness))
        ]
        switch event.type {
        case .transient:
            return CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: event.time)
        case .continuous:
            return CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: parameters,
                relativeTime: event.time,
                duration: event.duration ?? 0.1
            )
        }
    }

    /// A continuous event's ramp, as a curve that scales its peak intensity from the first value to the last.
    private static func intensityRamp(_ event: FWHapticPatterns.Event) -> CHHapticParameterCurve? {
        guard event.type == .continuous, event.intensity.count > 1, event.peakIntensity > 0 else { return nil }
        let duration = event.duration ?? 0.1
        let points = event.intensity.enumerated().map { index, value in
            CHHapticParameterCurve.ControlPoint(
                relativeTime: duration * Double(index) / Double(event.intensity.count - 1),
                value: Float(value / event.peakIntensity)
            )
        }
        return CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: points, relativeTime: event.time)
    }
}
