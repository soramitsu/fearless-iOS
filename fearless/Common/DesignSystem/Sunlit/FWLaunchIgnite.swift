import AVFoundation
import UIKit

/// The kit's launch timeline (`launch-timeline.json`, kit v3) and the hand-off timings of the SPEC's part 1.
struct FWLaunchTimeline: Decodable, Equatable {
    struct Point: Decodable, Equatable {
        let x: Double
        let y: Double
    }

    struct Focus: Decodable, Equatable {
        let phone: Point
        let popup: Point?
    }

    let fps: Int
    let durationSeconds: Double
    let fadeInSeconds: Double
    let holdSeconds: Double
    let zoomStartSeconds: Double
    let zoomEndSeconds: Double
    let background: String
    let focus: Focus

    /// The clip's pixel size (720 × 1560).
    static let videoSize = CGSize(width: 720, height: 1560)
    /// The screen underneath starts zooming in here.
    static let handOffStart: TimeInterval = 2.55
    static let underneathStartScale: CGFloat = 1.18
    static let underneathDuration: TimeInterval = 0.55
    /// The overlay scales up and fades out from here.
    static let overlayFadeStart: TimeInterval = 2.7
    static let overlayFadeDuration: TimeInterval = 0.45
    static let overlayEndScale: CGFloat = 1.6
    static let arriveHapticTime: TimeInterval = 2.6
    /// A tap jumps straight to the zoom, which then takes this long.
    static let skipDuration: TimeInterval = 0.3
    /// The launch screen's crest fades out while the clip fades up from ink.
    static let crestCrossfade: TimeInterval = 0.3
    /// A clip that will not start, or stops advancing, for longer than this is dropped with a plain fade.
    static let stallLimit: TimeInterval = 1.0
    /// Startup slower than this past the hold point is revealed anyway: the start screen then shows its own
    /// "keep Fearless open" status, which the overlay must not hide.
    static let holdLimit: TimeInterval = 3.0
    /// A later unlock lands in the wallet with this smaller zoom.
    static let landingStartScale: CGFloat = 1.06
    static let landingDuration: TimeInterval = 0.35

    /// Used when the bundled timeline cannot be read: the kit v3 values.
    static let kitV3 = FWLaunchTimeline(
        fps: 30, durationSeconds: 2.9, fadeInSeconds: 0.3, holdSeconds: 2, zoomStartSeconds: 2, zoomEndSeconds: 2.75,
        background: "#120A2E", focus: Focus(phone: Point(x: 0.5, y: 0.3292), popup: Point(x: 0.5, y: 0.4625))
    )

    static func bundled(_ bundle: Bundle = .main) -> FWLaunchTimeline? {
        guard let url = bundle.url(forResource: "launch-timeline", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(FWLaunchTimeline.self, from: data)
    }

    /// The clip's frame in `bounds`: aspect-fill, with the focus point at the centre as far as the frame allows.
    static func videoFrame(in bounds: CGRect, focus: Point, videoSize: CGSize = videoSize) -> CGRect {
        guard bounds.width > 0, bounds.height > 0, videoSize.width > 0, videoSize.height > 0 else { return bounds }
        let scale = max(bounds.width / videoSize.width, bounds.height / videoSize.height)
        let size = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        func origin(length: CGFloat, view: CGFloat, start: CGFloat, fraction: Double) -> CGFloat {
            let ideal = start + view / 2 - CGFloat(fraction) * length
            return min(start, max(start + view - length, ideal))
        }
        return CGRect(
            x: origin(length: size.width, view: bounds.width, start: bounds.minX, fraction: focus.x),
            y: origin(length: size.height, view: bounds.height, start: bounds.minY, fraction: focus.y),
            width: size.width,
            height: size.height
        )
    }

    /// Where the dive ends on screen.
    static func focusPoint(in bounds: CGRect, focus: Point, videoSize: CGSize = videoSize) -> CGPoint {
        let frame = videoFrame(in: bounds, focus: focus, videoSize: videoSize)
        return CGPoint(x: frame.minX + CGFloat(focus.x) * frame.width, y: frame.minY + CGFloat(focus.y) * frame.height)
    }

    /// A scale about `point` (in a layer whose anchor is its centre, `center`).
    static func scale(_ scale: CGFloat, about point: CGPoint, center: CGPoint) -> CATransform3D {
        let dx = point.x - center.x, dy = point.y - center.y
        var transform = CATransform3DMakeTranslation(dx, dy, 0)
        transform = CATransform3DScale(transform, scale, scale, 1)
        return CATransform3DTranslate(transform, -dx, -dy, 0)
    }
}

/// The launch overlay's decisions, kept free of UIKit so they can be tested.
enum FWLaunchSchedule {
    enum Step: Equatable {
        case keepPlaying
        case hold
        case resume
        case handOff
    }

    /// At the hold point the clip pauses only while the screen underneath is not ready.
    static func atHoldPoint(screenReady: Bool) -> Step {
        screenReady ? .keepPlaying : .hold
    }

    /// While held, the clip resumes as soon as the screen is ready, or once the hold has lasted too long.
    static func whileHolding(screenReady: Bool, heldFor: TimeInterval) -> Step {
        screenReady || heldFor >= FWLaunchTimeline.holdLimit ? .resume : .hold
    }

    /// The clip is stalled when it should be moving and has not moved for longer than the limit.
    static func isStalled(lastProgress: TimeInterval, now: TimeInterval, held: Bool) -> Bool {
        !held && now - lastProgress > FWLaunchTimeline.stallLimit
    }

    /// The overlay plays once per process, on a cold start in the foreground, never for tests or automation,
    /// with VoiceOver running (a silent decorative clip would only delay the first screen), or when
    /// motion is restricted (then the crest fades straight to the first screen).
    enum Mode: Equatable {
        case none
        case still
        case clip
    }

    static func mode(
        alreadyPlayed: Bool,
        disabled: Bool,
        background: Bool,
        voiceOver: Bool,
        motionRestricted: Bool,
        clipAvailable: Bool
    ) -> Mode {
        if alreadyPlayed || disabled || background || voiceOver { return .none }
        return motionRestricted || !clipAvailable ? .still : .clip
    }
}

/// Whether the screen under the launch overlay can be revealed.
protocol FWLaunchSplashScreen: UIViewController {}

enum FWLaunchReadiness {
    /// Ready once the start flow has installed its first real screen (or put a failure on the splash). Not while a
    /// system biometric prompt is up: the app is inactive then.
    static func isReady(rootViewController: UIViewController?, applicationActive: Bool) -> Bool {
        guard applicationActive, let root = rootViewController else { return false }
        if root is FWLaunchSplashScreen {
            return root.presentedViewController != nil
        }
        return true
    }
}

/// The Ignite launch (brand kit v3, "Launch, feel and sound", part 1): an overlay window over the normal start flow.
/// The start flow (PIN, welcome, wallet) loads underneath exactly as before; the overlay only covers it and then
/// zooms into it. It never delays, reorders or replaces authentication, and it is silent.
final class FWLaunchIgnite: NSObject {
    /// True while an overlay is on screen. Sounds wait until it is gone: a launch never makes a sound.
    private(set) static var isShowing = false
    private static var hasRun = false
    /// Launch argument for automation that needs the first screen at once.
    static let disableArgument = "-FWLaunchIgniteDisabled"

    private enum Phase: Equatable {
        case waitingForFirstFrame
        case playing
        case holding(since: TimeInterval)
        case handingOff
        case finished
    }

    private let mainWindow: UIWindow
    private let overlayWindow: UIWindow
    private let overlay = FWLaunchOverlayViewController()
    private let timeline: FWLaunchTimeline
    private let feedback: FWFeedbackPlaying
    private var player: AVPlayer?
    private var readyObservation: NSKeyValueObservation?
    private var boundaryObserver: Any?
    private var watchdog: Timer?
    private var phase = Phase.waitingForFirstFrame
    private var installedAt: TimeInterval = 0
    private var lastProgressTime: TimeInterval = 0
    private var lastClipTime: Double = -1
    private var observations: [NSObjectProtocol] = []
    private static var current: FWLaunchIgnite?

    /// Installs the overlay over `window` when this is the process's first scene connection. Call it right after
    /// the window becomes visible, before the first frame.
    @discardableResult
    static func installIfNeeded(
        over window: UIWindow,
        in scene: UIWindowScene,
        processInfo: ProcessInfo = .processInfo,
        effects: FWEffects = .shared
    ) -> FWLaunchIgnite? {
        let url = Bundle.main.url(forResource: "launch-ignite", withExtension: "mp4")
        let mode = FWLaunchSchedule.mode(
            alreadyPlayed: hasRun,
            disabled: processInfo.arguments.contains(disableArgument) || processInfo.arguments.contains("-UNITTEST"),
            background: scene.activationState == .background,
            voiceOver: UIAccessibility.isVoiceOverRunning,
            motionRestricted: FWMotionPolicy.current(effects: effects).isRestricted,
            clipAvailable: url != nil
        )
        hasRun = true
        guard mode != .none else { return nil }
        let launch = FWLaunchIgnite(
            mainWindow: window,
            scene: scene,
            timeline: FWLaunchTimeline.bundled() ?? .kitV3,
            feedback: FWFeedback.shared
        )
        current = launch
        launch.start(clip: mode == .clip ? url : nil)
        return launch
    }

    private init(mainWindow: UIWindow, scene: UIWindowScene, timeline: FWLaunchTimeline, feedback: FWFeedbackPlaying) {
        self.mainWindow = mainWindow
        self.timeline = timeline
        self.feedback = feedback
        overlayWindow = UIWindow(windowScene: scene)
        super.init()
        // Below the WalletConnect windows and the app-switcher cover, above the start flow. Never key, so text fields
        // underneath keep the keyboard.
        overlayWindow.windowLevel = UIWindow.Level.normal + 1
        overlayWindow.backgroundColor = .clear
        overlayWindow.rootViewController = overlay
        overlay.onTap = { [weak self] in self?.skip() }
    }

    private func start(clip url: URL?) {
        Self.isShowing = true
        installedAt = ProcessInfo.processInfo.systemUptime
        overlayWindow.isHidden = false
        observations.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.finish() })
        guard let url else {
            startStill()
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        self.player = player
        overlay.attach(player: player, focus: timeline.focus.phone)
        readyObservation = overlay.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            guard layer.isReadyForDisplay else { return }
            DispatchQueue.main.async { self?.firstFrameReady() }
        }
        let times = [timeline.holdSeconds, FWLaunchTimeline.handOffStart].map {
            NSValue(time: CMTime(seconds: $0, preferredTimescale: 600))
        }
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: times, queue: .main) { [weak self] in
            self?.boundaryReached()
        }
        startWatchdog()
    }

    /// Reduce Motion, Reduced effects or a missing clip: the crest on ink, fading straight to the first screen.
    private func startStill() {
        phase = .holding(since: ProcessInfo.processInfo.systemUptime)
        startWatchdog()
    }

    private func firstFrameReady() {
        guard case .waitingForFirstFrame = phase, let player else { return }
        phase = .playing
        lastProgressTime = ProcessInfo.processInfo.systemUptime
        player.play()
        overlay.fadeCrest(duration: FWLaunchTimeline.crestCrossfade)
    }

    private func boundaryReached() {
        guard let player else { return }
        let time = player.currentTime().seconds
        switch phase {
        case .playing where time < FWLaunchTimeline.handOffStart - 0.05:
            if FWLaunchSchedule.atHoldPoint(screenReady: screenReady) == .hold {
                player.pause()
                player.seek(to: CMTime(seconds: timeline.holdSeconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                phase = .holding(since: ProcessInfo.processInfo.systemUptime)
            }
        case .playing:
            handOff(duration: nil)
        default:
            break
        }
    }

    private var screenReady: Bool {
        FWLaunchReadiness.isReady(
            rootViewController: mainWindow.rootViewController,
            applicationActive: UIApplication.shared.applicationState == .active
        )
    }

    private func startWatchdog() {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        switch phase {
        case .waitingForFirstFrame:
            if now - installedAt > FWLaunchTimeline.stallLimit || player?.currentItem?.status == .failed {
                abandon()
            }
        case .playing:
            guard let player, player.currentItem?.status != .failed else {
                abandon()
                return
            }
            let time = player.currentTime().seconds
            if time > lastClipTime + 0.001 {
                lastClipTime = time
                lastProgressTime = now
            } else if FWLaunchSchedule.isStalled(lastProgress: lastProgressTime, now: now, held: false) {
                abandon()
            }
        case let .holding(since):
            guard FWLaunchSchedule.whileHolding(screenReady: screenReady, heldFor: now - since) == .resume else { return }
            guard let player else {
                // The still crest: fade straight to the first screen.
                abandon()
                return
            }
            phase = .playing
            lastProgressTime = now
            lastClipTime = player.currentTime().seconds
            player.play()
        case .handingOff, .finished:
            break
        }
    }

    private func skip() {
        switch phase {
        case .waitingForFirstFrame, .playing, .holding:
            handOff(duration: FWLaunchTimeline.skipDuration)
        case .handingOff, .finished:
            break
        }
    }

    /// The zoom: the screen underneath comes in from 1.18 while the overlay scales up and fades out around the
    /// dive's focus point. `duration` is set for a tap, which jumps straight to it.
    private func handOff(duration: TimeInterval?) {
        phase = .handingOff
        stopTimers()
        player?.play()
        let bounds = mainWindow.bounds
        let focus = FWLaunchTimeline.focusPoint(in: bounds, focus: timeline.focus.phone)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let underneath = duration ?? FWLaunchTimeline.underneathDuration
        let fadeDelay = duration == nil ? FWLaunchTimeline.overlayFadeStart - FWLaunchTimeline.handOffStart : 0
        let fade = duration ?? FWLaunchTimeline.overlayFadeDuration

        let decelerate = CAMediaTimingFunction(controlPoints: 0.16, 0.84, 0.3, 1)
        let zoom = CABasicAnimation(keyPath: "transform")
        zoom.fromValue = FWLaunchTimeline.scale(FWLaunchTimeline.underneathStartScale, about: focus, center: center)
        zoom.toValue = CATransform3DIdentity
        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0
        appear.toValue = 1
        let group = CAAnimationGroup()
        group.animations = [zoom, appear]
        group.duration = underneath
        group.timingFunction = decelerate
        mainWindow.layer.add(group, forKey: "fw.launch.landing")

        let hapticDelay = duration == nil ? FWLaunchTimeline.arriveHapticTime - FWLaunchTimeline.handOffStart : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + hapticDelay) { [feedback] in
            feedback.play(.launchArrive)
        }

        guard let overlayView = overlay.viewIfLoaded else {
            finish()
            return
        }
        let overlayFocus = overlayView.convert(focus, from: mainWindow)
        UIView.animate(withDuration: fade, delay: fadeDelay, options: [.curveEaseIn, .beginFromCurrentState]) {
            overlayView.layer.transform = FWLaunchTimeline.scale(
                FWLaunchTimeline.overlayEndScale,
                about: overlayFocus,
                center: CGPoint(x: overlayView.bounds.midX, y: overlayView.bounds.midY)
            )
            overlayView.alpha = 0
        } completion: { [weak self] _ in
            self?.finish()
        }
    }

    /// The clip could not load or stalled: a plain fade to whatever is underneath.
    private func abandon() {
        guard !isFinishing else { return }
        phase = .handingOff
        stopTimers()
        UIView.animate(withDuration: FWLaunchTimeline.crestCrossfade, delay: 0, options: [.curveEaseOut]) {
            self.overlay.view.alpha = 0
        } completion: { [weak self] _ in
            self?.finish()
        }
    }

    private var isFinishing: Bool {
        phase == .handingOff || phase == .finished
    }

    private func stopTimers() {
        watchdog?.invalidate()
        watchdog = nil
        if let boundaryObserver { player?.removeTimeObserver(boundaryObserver) }
        boundaryObserver = nil
        readyObservation = nil
    }

    private func finish() {
        guard phase != .finished else { return }
        phase = .finished
        stopTimers()
        observations.forEach(NotificationCenter.default.removeObserver)
        observations = []
        player?.pause()
        player = nil
        overlay.detach()
        overlayWindow.isHidden = true
        overlayWindow.rootViewController = nil
        Self.isShowing = false
        Self.current = nil
    }
}

/// Ink, the clip and the launch screen's crest on top of it until the clip's first frame shows.
final class FWLaunchOverlayViewController: UIViewController {
    let playerLayer = AVPlayerLayer()
    private let crestView = UIImageView(image: R.image.logo())
    private var focus = FWLaunchTimeline.kitV3.focus.phone
    var onTap: (() -> Void)?

    override func loadView() {
        let view = UIView()
        view.backgroundColor = FWSunlit.Palette.background
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        playerLayer.videoGravity = .resize
        playerLayer.backgroundColor = nil
        view.layer.addSublayer(playerLayer)
        crestView.contentMode = .scaleAspectFit
        view.addSubview(crestView)
        // The launch screen's crest: 120 pt, centred across the screen and on the safe area's middle.
        crestView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(view.safeAreaLayoutGuide)
            make.size.equalTo(RootViewLayout.logoSide)
        }
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        self.view = view
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = FWLaunchTimeline.videoFrame(in: view.bounds, focus: focus)
        CATransaction.commit()
    }

    func attach(player: AVPlayer, focus: FWLaunchTimeline.Point) {
        self.focus = focus
        playerLayer.player = player
        view.setNeedsLayout()
    }

    func detach() {
        playerLayer.player = nil
    }

    func fadeCrest(duration: TimeInterval) {
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut]) {
            self.crestView.alpha = 0
        }
    }

    @objc private func tapped() {
        onTap?()
    }
}

/// A later unlock lands in the wallet: the old screen crossfades while the wallet settles from 1.06 to 1 (0.35 s).
/// Reduced motion keeps the crossfade alone.
final class FWLandingAnimationCoordinator: RootControllerAnimationCoordinatorProtocol {
    private let effects: FWEffects

    init(effects: FWEffects = .shared) {
        self.effects = effects
    }

    func animateTransition(to controller: UIViewController, in window: UIWindow) {
        let restricted = FWMotionPolicy.current(effects: effects).isRestricted
        let fade = CATransition()
        fade.type = .fade
        fade.duration = restricted ? 0.3 : FWLaunchTimeline.landingDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        window.rootViewController = controller
        window.layer.add(fade, forKey: "window.root.transition")
        guard !restricted else { return }
        let settle = CABasicAnimation(keyPath: "transform.scale")
        settle.fromValue = FWLaunchTimeline.landingStartScale
        settle.toValue = 1
        settle.duration = FWLaunchTimeline.landingDuration
        settle.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.84, 0.3, 1)
        controller.view.layer.add(settle, forKey: "fw.landing.settle")
    }
}
