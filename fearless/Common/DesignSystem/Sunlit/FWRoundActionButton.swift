import UIKit

/// Press feedback shared by sun-lit controls: the surface sinks from raised to inset (shadows swap) and the
/// control scales to 0.97, 90 ms in and a 160 ms spring out. Reduced motion and Calm keep the swap only.
enum FWPress {
    /// Every way a touch leaves a control.
    static let releaseEvents: UIControl.Event = [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit]

    static func apply(
        _ pressed: Bool,
        to control: UIView,
        surface: FWNeuView?,
        effects: FWEffects = .shared,
        calm: Bool = false,
        pressedScale: CGFloat? = nil
    ) {
        surface?.setPressed(pressed, animated: true)
        let policy = FWMotionPolicy.current(effects: effects, calm: calm)
        let allowed = policy.pressScale == 1 ? 1 : (pressedScale ?? policy.pressScale)
        let scale = pressed ? allowed : 1
        let transform = scale == 1 ? CGAffineTransform.identity : CGAffineTransform(scaleX: scale, y: scale)
        guard control.transform != transform else { return }
        if pressed {
            UIView.animate(
                withDuration: FWSunlit.Motion.pressIn, delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
            ) { control.transform = transform }
        } else {
            UIView.animate(
                withDuration: FWSunlit.Motion.pressOut, delay: 0, usingSpringWithDamping: 0.62,
                initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction]
            ) { control.transform = transform }
        }
    }
}

/// A 60 pt round action (Send, Receive, Buy, Swap) with its caption underneath. The emissive variant marks
/// the primary action of a screen.
final class FWRoundActionButton: UIControl {
    let surface: FWNeuView
    let iconView = UIImageView()
    let titleLabel = UILabel()
    private let effects: FWEffects
    private var locale = Locale.current
    static let diameter: CGFloat = 60
    /// Round actions press deeper than other controls, with a spring back (kit v3 design pass).
    static let pressedScale: CGFloat = 0.94
    /// The primary action's slow sheen: one sweep every 6 s.
    static let sheenPeriod: TimeInterval = 6
    static let sheenSweep: TimeInterval = 0.9
    private let sheenLayer = CAGradientLayer()
    private let sheenMask = CAShapeLayer()
    private var effectsObservation: NSObjectProtocol?

    /// The pink primary action carries a slow sheen while motion is allowed.
    var sheen = false {
        didSet { updateSheen() }
    }

    var emissive = false {
        didSet { applyStyle() }
    }

    var sunRim: CGFloat {
        get { surface.sunRim }
        set { surface.sunRim = newValue }
    }

    init(icon: UIImage?, effects: FWEffects = .shared) {
        self.effects = effects
        surface = FWNeuView(effects: effects)
        super.init(frame: .zero)
        surface.isUserInteractionEnabled = false
        surface.isInteractive = true
        surface.shape = { UIBezierPath(ovalIn: $0) }
        iconView.image = icon?.withRenderingMode(.alwaysTemplate)
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.isUserInteractionEnabled = false
        titleLabel.textColor = FWSunlit.Palette.textSecondary
        addSubview(surface)
        surface.addSubview(iconView)
        addSubview(titleLabel)
        surface.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(Self.diameter)
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(surface.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview()
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
        sheenLayer.colors = [UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 0.32), UIColor(white: 1, alpha: 0)]
            .map(\.cgColor)
        sheenLayer.startPoint = CGPoint(x: 0, y: 0.15)
        sheenLayer.endPoint = CGPoint(x: 1, y: 0.85)
        sheenLayer.locations = [-0.6, -0.4, -0.2]
        sheenLayer.mask = sheenMask
        sheenLayer.isHidden = true
        surface.layer.addSublayer(sheenLayer)
        effectsObservation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.updateSheen() }
        applyStyle()
    }

    deinit {
        if let effectsObservation { effects.notificationCenter.removeObserver(effectsObservation) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sheenLayer.frame = surface.bounds
        sheenMask.frame = surface.bounds
        sheenMask.path = UIBezierPath(ovalIn: surface.bounds).cgPath
        CATransaction.commit()
        // Keep the sheen above the surface's paint and below the icon.
        surface.bringSubviewToFront(iconView)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateSheen()
    }

    /// A crisp tap when a round action is pressed (phones; the user's Haptic feedback switch applies).
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        FWFeedback.shared.play(.commit)
        return super.beginTracking(touch, with: event)
    }

    private func updateSheen() {
        sheenLayer.removeAnimation(forKey: "fw.sheen")
        let animates = sheen && isEnabled && window != nil && !FWMotionPolicy.current(effects: effects).isRestricted
        sheenLayer.isHidden = !animates
        guard animates else { return }
        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-0.6, -0.4, -0.2]
        sweep.toValue = [1.2, 1.4, 1.6]
        sweep.duration = Self.sheenSweep
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        let period = CAAnimationGroup()
        period.animations = [sweep]
        period.duration = Self.sheenPeriod
        period.repeatCount = .infinity
        period.beginTime = CACurrentMediaTime() + 2
        period.isRemovedOnCompletion = false
        sheenLayer.add(period, forKey: "fw.sheen")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, locale: Locale) {
        self.locale = locale
        titleLabel.text = title
        accessibilityLabel = title
        applyTypography()
    }

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            FWPress.apply(
                isHighlighted, to: surface, surface: surface, effects: effects, pressedScale: Self.pressedScale
            )
        }
    }

    override var isEnabled: Bool {
        didSet {
            applyStyle()
            updateSheen()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight {
            applyTypography()
        }
    }

    private func applyTypography() {
        titleLabel.font = .fw(.labelS, locale: locale, compatibleWith: traitCollection)
    }

    private func applyStyle() {
        surface.style = isEnabled ? (emissive ? .emissive : .raised) : .inset
        iconView.tintColor = !isEnabled ? FWSunlit.Palette.textTertiary :
            (emissive ? .white : FWSunlit.Palette.textPrimary)
        titleLabel.textColor = isEnabled ? FWSunlit.Palette.textSecondary : FWSunlit.Palette.textTertiary
        accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
    }
}

/// A button whose surface sits behind its image and title, whenever UIKit adds them.
final class FWSurfaceButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        [imageView, titleLabel].compactMap { $0 }.forEach(bringSubviewToFront)
    }
}

/// A 44 pt round icon button (search, scan, back, more): a Raised-1 circle that sinks when pressed.
enum FWRoundIconButton {
    static func make(image: UIImage?, tint: UIColor = FWSunlit.Palette.textSecondary) -> UIButton {
        let button = FWSurfaceButton()
        button.setImage(image?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = tint
        button.backgroundColor = .clear
        let surface = FWNeuView()
        surface.style = .raised1
        surface.isInteractive = true
        surface.isUserInteractionEnabled = false
        surface.shape = { UIBezierPath(ovalIn: $0) }
        surface.frame = button.bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        button.insertSubview(surface, at: 0)
        button.addAction(for: [.touchDown, .touchDragEnter]) { [weak button, weak surface] in
            guard let button = button else { return }
            FWPress.apply(true, to: button, surface: surface)
        }
        button.addAction(for: FWPress.releaseEvents) { [weak button, weak surface] in
            guard let button = button else { return }
            FWPress.apply(false, to: button, surface: surface)
        }
        return button
    }
}
