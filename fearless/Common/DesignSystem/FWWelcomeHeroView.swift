import AVFoundation
import UIKit

/// The welcome hero (Yatagarasu brand, 2026-11-10): the animated crow full-bleed behind the top of the page,
/// aspect-fill and anchored to the top, over its poster.
///
/// - The loop is muted and has no audio track, so it never touches the audio session. It plays only while the view is
///   in a window, the app is not in the background and motion is allowed; otherwise it pauses.
/// - Reduce Motion (and the app's Reduced effects) show the poster alone and never autoplay.
/// - `playCall()` plays the crow's call once with sound: a 250 ms crossfade from the loop into the clip and back. The
///   clip starts and ends on the loop's first pose, so the loop restarts there. Calls during a call are ignored. With
///   motion restricted the call's sound plays alone over the still poster.
/// - Sound follows the device: the `.ambient` category lets the silent switch mute it and mixes with other audio.
/// The footage is decorative and hidden from assistive technologies; the welcome page owns the labelled tap target.
final class FWWelcomeHeroView: UIView {
    struct Media {
        let loop: URL?
        let call: URL?
        let sound: URL?
        let poster: URL?

        static var bundled: Media {
            let bundle = Bundle(for: FWWelcomeHeroView.self)
            return Media(
                loop: bundle.url(forResource: "welcome-idle", withExtension: "mp4"),
                call: bundle.url(forResource: "welcome-caw", withExtension: "mp4"),
                sound: bundle.url(forResource: "welcome-caw", withExtension: "m4a"),
                poster: bundle.url(forResource: "welcome-poster", withExtension: "webp")
            )
        }
    }

    /// The audio session's category, kept to restore after a call.
    private struct AudioCategory {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
    }

    /// The crossfade between the loop and the call, both ways.
    static let crossfade: TimeInterval = 0.25
    /// The footage's pixel size (both clips and the poster are 720 × 1560).
    static let footageSize = CGSize(width: 720, height: 1560)

    let posterView = UIImageView()
    let loopLayer = AVPlayerLayer()
    let callLayer = AVPlayerLayer()

    private let media: Media
    private let effects: FWEffects
    private let lifecycle: NotificationCenter
    private var observations: [NSObjectProtocol] = []
    private var loopPlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var callPlayer: AVPlayer?
    private var callEnd: NSObjectProtocol?
    private var soundPlayer: AVAudioPlayer?
    private var previousAudioCategory: AudioCategory?
    private var inBackground: Bool

    /// True from a call's start until its crossfade back has finished.
    private(set) var isPlayingCall = false

    /// Whether the loop is set up and asked to play (it may still be loading its first frame).
    var isLooping: Bool {
        guard let loopPlayer else { return false }
        return loopPlayer.rate != 0 || loopPlayer.timeControlStatus != .paused
    }

    /// Whether motion settings keep the hero still: the poster alone.
    var showsPosterOnly: Bool {
        FWMotionPolicy.current(effects: effects).isRestricted || media.loop == nil
    }

    init(media: Media = .bundled, effects: FWEffects = .shared, lifecycle: NotificationCenter = .default) {
        self.media = media
        self.effects = effects
        self.lifecycle = lifecycle
        inBackground = UIApplication.shared.applicationState == .background
        super.init(frame: .zero)
        backgroundColor = FWSunlit.Palette.background
        clipsToBounds = true
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        posterView.image = media.poster.flatMap { UIImage(contentsOfFile: $0.path) }
        posterView.contentMode = .scaleToFill
        addSubview(posterView)
        for playerLayer in [loopLayer, callLayer] {
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = nil
            layer.addSublayer(playerLayer)
        }
        callLayer.opacity = 0
        let effectsChange = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.updatePlayback() }
        let background = lifecycle.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.inBackground = true
            self?.updatePlayback()
        }
        let foreground = lifecycle.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.inBackground = false
            self?.updatePlayback()
        }
        observations = [effectsChange, background, foreground]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observations.forEach { effects.notificationCenter.removeObserver($0); lifecycle.removeObserver($0) }
        if let callEnd { NotificationCenter.default.removeObserver(callEnd) }
        looper?.disableLooping()
        loopPlayer?.pause()
        callPlayer?.pause()
        soundPlayer?.stop()
        restoreAudioCategory()
    }

    /// The footage's frame: aspect-fill, anchored to the top and centred across.
    static func footageFrame(in bounds: CGRect) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = max(bounds.width / footageSize.width, bounds.height / footageSize.height)
        let size = CGSize(width: footageSize.width * scale, height: footageSize.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.minY, width: size.width, height: size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let footage = Self.footageFrame(in: bounds)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        posterView.frame = footage
        loopLayer.frame = footage
        callLayer.frame = footage
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updatePlayback()
    }

    override var isHidden: Bool {
        didSet { updatePlayback() }
    }

    // MARK: - The call

    /// Plays the crow's call once with sound. Ignored while a call plays or when there is nothing to play.
    func playCall() {
        guard !isPlayingCall, window != nil, !inBackground else { return }
        if showsPosterOnly {
            guard let url = media.sound, let player = try? AVAudioPlayer(contentsOf: url) else { return }
            isPlayingCall = true
            useAmbientAudio()
            player.delegate = self
            soundPlayer = player
            if !player.play() { endCall() }
            return
        }
        guard let url = media.call else { return }
        isPlayingCall = true
        useAmbientAudio()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        callPlayer = player
        callLayer.player = player
        callEnd = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in self?.finishClip() }
        player.play()
        crossfade(to: callLayer) { [weak self] in
            // The loop waits, hidden, while the call plays.
            guard let self, self.isPlayingCall else { return }
            self.loopPlayer?.pause()
        }
    }

    private func finishClip() {
        guard isPlayingCall else { return }
        if let callEnd { NotificationCenter.default.removeObserver(callEnd) }
        callEnd = nil
        // The clip ends on the loop's first pose: restart the loop there before fading back to it.
        if wantsLoop, let loopPlayer {
            loopPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            loopPlayer.play()
        }
        crossfade(to: loopLayer) { [weak self] in
            guard let self else { return }
            self.callLayer.player = nil
            self.callPlayer = nil
            self.endCall()
        }
    }

    /// Stops a call at once (backgrounded, off screen or motion now restricted) and shows the loop or poster again.
    private func cancelCall() {
        guard isPlayingCall else { return }
        if let callEnd { NotificationCenter.default.removeObserver(callEnd) }
        callEnd = nil
        callPlayer?.pause()
        callPlayer = nil
        soundPlayer?.stop()
        soundPlayer = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        loopLayer.removeAllAnimations()
        callLayer.removeAllAnimations()
        callLayer.player = nil
        callLayer.opacity = 0
        loopLayer.opacity = 1
        CATransaction.commit()
        endCall()
    }

    private func endCall() {
        isPlayingCall = false
        restoreAudioCategory()
        updatePlayback()
    }

    private func crossfade(to target: AVPlayerLayer, completion: @escaping () -> Void) {
        let other = target === callLayer ? loopLayer : callLayer
        CATransaction.begin()
        CATransaction.setAnimationDuration(Self.crossfade)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        CATransaction.setCompletionBlock(completion)
        target.opacity = 1
        other.opacity = 0
        CATransaction.commit()
    }

    /// The silent switch mutes the call and other apps' audio keeps playing; the previous category comes back after.
    private func useAmbientAudio() {
        let session = AVAudioSession.sharedInstance()
        if previousAudioCategory == nil {
            previousAudioCategory = AudioCategory(
                category: session.category, mode: session.mode, options: session.categoryOptions
            )
        }
        try? session.setCategory(.ambient, mode: .default, options: [])
    }

    private func restoreAudioCategory() {
        guard let previous = previousAudioCategory else { return }
        previousAudioCategory = nil
        try? AVAudioSession.sharedInstance().setCategory(
            previous.category, mode: previous.mode, options: previous.options
        )
    }

    // MARK: - The loop

    private var wantsLoop: Bool {
        window != nil && !isHidden && !inBackground && !showsPosterOnly
    }

    private func updatePlayback() {
        if isPlayingCall, window == nil || inBackground || (callPlayer != nil && showsPosterOnly) {
            cancelCall()
            return
        }
        if showsPosterOnly {
            releaseLoop()
            return
        }
        guard wantsLoop else {
            loopPlayer?.pause()
            return
        }
        guard !isPlayingCall else { return }
        startLoop()
    }

    private func startLoop() {
        if loopPlayer == nil, let url = media.loop {
            let player = AVQueuePlayer()
            player.isMuted = true
            player.preventsDisplaySleepDuringVideoPlayback = false
            player.allowsExternalPlayback = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            loopPlayer = player
            loopLayer.player = player
        }
        loopPlayer?.play()
    }

    private func releaseLoop() {
        looper?.disableLooping()
        looper = nil
        loopPlayer?.pause()
        loopPlayer = nil
        loopLayer.player = nil
    }
}

extension FWWelcomeHeroView: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        soundPlayer = nil
        endCall()
    }

    func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error _: Error?) {
        soundPlayer = nil
        endCall()
    }
}
