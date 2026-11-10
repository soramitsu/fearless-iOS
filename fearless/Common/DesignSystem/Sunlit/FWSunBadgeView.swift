import UIKit

/// The round crest badge (Yatagarasu brand 2026-11-10) as the scene's emissive light, its "sun" (redesign spec
/// sections 2 and 4). While the wallet syncs a thin arc of light sweeps around it (its length is the progress when
/// known); when the sync finishes the glow blooms once; when networks cannot be reached the badge dims and a small
/// warning dot appears.
final class FWSunBadgeView: UIView {
    let imageView = UIImageView()
    private let glow = CAGradientLayer()
    private let arc = CAGradientLayer()
    private let arcMask = CAShapeLayer()
    private let warningDot = UIView()
    private let effects: FWEffects
    private var observation: NSObjectProtocol?
    private(set) var syncState: FWSyncState = .idle

    /// Calm surfaces never animate beyond press feedback.
    var calm = false { didSet { applyEffects() } }

    /// The default arc while the progress is unknown.
    static let indeterminateArc: CGFloat = 0.23
    static let restingGlow: Float = 0.85

    init(effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        imageView.image = R.image.fwCrestBadge()
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = false
        imageView.layer.shadowColor = FWSunlit.Palette.gradientEnd.cgColor
        imageView.layer.shadowOpacity = 0.7
        imageView.layer.shadowOffset = CGSize(width: 0, height: 6)
        imageView.layer.shadowRadius = 7
        glow.type = .radial
        glow.colors = [
            FWSunlit.Palette.sun.withAlphaComponent(0.55),
            FWSunlit.Palette.brand.withAlphaComponent(0.18),
            FWSunlit.Palette.brand.withAlphaComponent(0)
        ].map(\.cgColor)
        glow.locations = [0, 0.45, 1]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.opacity = Self.restingGlow
        layer.addSublayer(glow)
        addSubview(imageView)
        arcMask.fillColor = nil
        arcMask.strokeColor = UIColor.black.cgColor
        arcMask.lineWidth = 2.5
        arcMask.lineCap = .round
        arc.type = .conic
        arc.startPoint = CGPoint(x: 0.5, y: 0.5)
        arc.endPoint = CGPoint(x: 0.5, y: 0)
        arc.mask = arcMask
        arc.isHidden = true
        layer.addSublayer(arc)
        warningDot.backgroundColor = FWSunlit.Palette.warning
        warningDot.layer.borderColor = FWSunlit.Palette.background.cgColor
        warningDot.layer.borderWidth = 2
        warningDot.alpha = 0
        warningDot.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        warningDot.isAccessibilityElement = false
        addSubview(warningDot)
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.applyEffects() }
        applyEffects()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observation {
            effects.notificationCenter.removeObserver(observation)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyEffects()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyEffects()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = min(bounds.width, bounds.height)
        let badgeSide = side * 0.875
        let badge = CGRect(
            x: bounds.midX - badgeSide / 2, y: bounds.midY - badgeSide / 2, width: badgeSide, height: badgeSide
        )
        imageView.frame = badge
        imageView.layer.shadowPath = UIBezierPath(ovalIn: imageView.bounds).cgPath
        let glowSide = side * 1.4
        glow.frame = CGRect(
            x: bounds.midX - glowSide / 2, y: bounds.midY - glowSide / 2, width: glowSide, height: glowSide
        )
        arc.frame = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
        arcMask.frame = arc.bounds
        let radius = side / 2 - arcMask.lineWidth
        arcMask.path = UIBezierPath(
            arcCenter: CGPoint(x: side / 2, y: side / 2), radius: radius,
            startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true
        ).cgPath
        let dot: CGFloat = max(10, side * 0.09)
        warningDot.frame = CGRect(x: badge.maxX - dot * 1.1, y: badge.minY + dot * 0.1, width: dot, height: dot)
        warningDot.layer.cornerRadius = dot / 2
        CATransaction.commit()
    }

    /// Shows `state`; only a change of state animates, each with its own informative motion.
    func setSyncState(_ state: FWSyncState, animated: Bool) {
        let previous = syncState
        syncState = state
        let policy = FWMotionPolicy.current(effects: effects, calm: calm)
        switch state {
        case let .syncing(progress):
            showArc(progress: progress, policy: policy)
            setFailed(false, animated: animated, policy: policy)
        case .synced:
            hideArc(animated: animated)
            setFailed(false, animated: animated, policy: policy)
            if animated, case .syncing = previous {
                bloom(policy: policy)
            }
        case .failed:
            hideArc(animated: animated)
            setFailed(true, animated: animated, policy: policy)
        case .idle:
            hideArc(animated: false)
            setFailed(false, animated: false, policy: policy)
        }
    }

    // MARK: - Sync arc

    private func showArc(progress: Double?, policy: FWMotionPolicy) {
        let length = progress.map { CGFloat(max(0.04, min(1, $0))) } ?? Self.indeterminateArc
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let light = FWSunlit.color(0xFFD6E8)
        arc.colors = [UIColor(white: 1, alpha: 0), light, light].map(\.cgColor)
        arc.locations = [0, NSNumber(value: Double(length)), 1]
        arcMask.strokeEnd = length
        arc.isHidden = false
        arc.opacity = 1
        CATransaction.commit()
        let turn = policy.style(for: .syncRunning)
        if window != nil, case let .full(duration) = turn, arc.animation(forKey: "turn") == nil {
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = 0
            rotation.toValue = 2 * Double.pi
            rotation.duration = duration
            rotation.repeatCount = .infinity
            rotation.isRemovedOnCompletion = false
            arc.add(rotation, forKey: "turn")
        } else if window == nil || !turn.animates {
            arc.removeAnimation(forKey: "turn")
        }
    }

    private func hideArc(animated: Bool) {
        guard !arc.isHidden else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? FWSunlit.Motion.maxCrossfade : 0)
        CATransaction.setDisableActions(!animated)
        CATransaction.setCompletionBlock { [weak self] in
            guard let self = self else { return }
            if case .syncing = self.syncState { return }
            self.arc.isHidden = true
            self.arc.removeAnimation(forKey: "turn")
        }
        arc.opacity = 0
        CATransaction.commit()
    }

    // MARK: - Finished and failed

    private func bloom(policy: FWMotionPolicy) {
        let style = policy.style(for: .syncFinished)
        guard style.animates else { return }
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.6, 1, Self.restingGlow]
        opacity.keyTimes = [0, 0.35, 1]
        opacity.duration = style.duration
        glow.add(opacity, forKey: "bloom")
        if case .full = style {
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [1, 1.08, 1]
            scale.keyTimes = [0, 0.35, 1]
            scale.duration = style.duration
            scale.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeInEaseOut)]
            glow.add(scale, forKey: "bloomScale")
        }
    }

    private func setFailed(_ failed: Bool, animated: Bool, policy: FWMotionPolicy) {
        let style = policy.style(for: .syncFailed)
        let duration = animated && style.animates ? style.duration : 0
        let changes = {
            self.imageView.alpha = failed ? FWSunlit.Motion.syncFailedSunAlpha : 1
            self.warningDot.alpha = failed ? 1 : 0
            self.warningDot.transform = failed ? .identity : CGAffineTransform(scaleX: 0.4, y: 0.4)
        }
        if duration > 0 {
            UIView.animate(
                withDuration: duration, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: changes
            )
        } else {
            changes()
        }
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setDisableActions(duration == 0)
        glow.opacity = failed ? Float(FWSunlit.Motion.syncFailedSunAlpha) * Self.restingGlow : Self.restingGlow
        CATransaction.commit()
    }

    private func applyEffects() {
        let plain = effects.paintReduced(calm: calm) || traitCollection.accessibilityContrast == .high
        glow.isHidden = plain
        imageView.layer.shadowOpacity = plain ? 0 : 0.7
        if window == nil || !FWMotionPolicy.current(effects: effects, calm: calm).style(for: .syncRunning).animates {
            arc.removeAnimation(forKey: "turn")
            glow.removeAllAnimations()
        } else if case let .syncing(progress) = syncState {
            showArc(progress: progress, policy: FWMotionPolicy.current(effects: effects, calm: calm))
        }
    }
}
