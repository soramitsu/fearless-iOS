import UIKit

/// Colours of the kit v3 design pass ("much cooler"): the lit rim and the plum shadow.
enum FWFeel {
    /// Lit rim: gold on the upper-left, through pink, to nothing on the lower-right.
    static let rimGold = FWSunlit.Palette.sun.withAlphaComponent(0.55)
    static let rimPink = FWSunlit.Palette.brandText.withAlphaComponent(0.30)
    /// The soft plum shadow under lit cards (kit plum #3A1060).
    static let plum = FWSunlit.color(0x3A1060)
    /// The aurora's ember (kit ember #FF7A1A).
    static let ember = FWSunlit.color(0xFF7A1A)
    /// Each aurora glow stays under 18 % at its centre.
    static let auroraAlpha: CGFloat = 0.16
    /// One aurora cycle.
    static let auroraCycle: TimeInterval = 60
    /// The sun in the sky card's image, as a fraction of its size.
    static let skySun = CGPoint(x: 0.519, y: 0.375)
    /// The scrim over the sky: lighter around the badge, strong enough under text that every text colour keeps 4.5:1.
    static let scrimTop: CGFloat = 0.3
    static let scrimText: CGFloat = 0.82
    static let scrimBottom: CGFloat = 0.88
}

/// A one-pixel lit rim along a rounded shape, with an inner top highlight.
final class FWLitRimLayer: CALayer {
    private let rim = CAGradientLayer()
    private let rimMask = CAShapeLayer()
    /// A brighter copy of the rim, shown only during a flash.
    private let bright = CAGradientLayer()
    private let brightMask = CAShapeLayer()
    private let highlight = CAGradientLayer()
    private let highlightMask = CAShapeLayer()

    var cornerRadiusValue: CGFloat = FWSunlit.Radius.card {
        didSet { setNeedsLayout() }
    }

    override init() {
        super.init()
        commonInit()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        rim.colors = [FWFeel.rimGold, FWFeel.rimPink, FWFeel.rimPink.withAlphaComponent(0)].map(\.cgColor)
        rim.locations = [0, 0.45, 1]
        rim.startPoint = CGPoint(x: 0, y: 0)
        rim.endPoint = CGPoint(x: 1, y: 1)
        rimMask.fillColor = nil
        rimMask.strokeColor = UIColor.black.cgColor
        rimMask.lineWidth = 1
        rim.mask = rimMask
        bright.colors = [FWSunlit.Palette.sun, FWSunlit.Palette.brandText.withAlphaComponent(0.7), FWSunlit.Palette.sun.withAlphaComponent(0)]
            .map(\.cgColor)
        bright.locations = [0, 0.5, 1]
        bright.startPoint = CGPoint(x: 0, y: 0)
        bright.endPoint = CGPoint(x: 1, y: 1)
        brightMask.fillColor = nil
        brightMask.strokeColor = UIColor.black.cgColor
        brightMask.lineWidth = 1.5
        bright.mask = brightMask
        bright.opacity = 0
        highlight.colors = [UIColor(white: 1, alpha: 0.10), UIColor(white: 1, alpha: 0)].map(\.cgColor)
        highlight.startPoint = CGPoint(x: 0.5, y: 0)
        highlight.endPoint = CGPoint(x: 0.5, y: 0.28)
        highlight.mask = highlightMask
        addSublayer(highlight)
        addSublayer(rim)
        addSublayer(bright)
    }

    /// Brightens the rim and lets it settle again over `duration`.
    func flash(duration: TimeInterval) {
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0, 1, 0]
        flash.keyTimes = [0, 0.25, 1]
        flash.duration = duration
        bright.add(flash, forKey: "fw.flash")
    }

    override func layoutSublayers() {
        super.layoutSublayers()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [rim, bright, highlight, rimMask, brightMask, highlightMask] {
            layer.frame = bounds
        }
        let inset = bounds.insetBy(dx: 0.5, dy: 0.5)
        let rimPath = UIBezierPath(roundedRect: inset, cornerRadius: max(0, cornerRadiusValue - 0.5)).cgPath
        rimMask.path = rimPath
        brightMask.path = rimPath
        highlightMask.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadiusValue).cgPath
        CATransaction.commit()
    }
}

/// The wallet's balance card (kit v3 design pass 1–2): the sunset sky, anchored on its sun behind the round badge,
/// the solar geometry turning slowly around the badge with the lattice faint behind, an ink scrim that keeps every
/// text on the card at 4.5:1 or more, a lit rim and a soft plum shadow. `pulse()` lights it in gold when tokens
/// arrive. Decorative: hidden from assistive technologies.
final class FWSkyCardView: UIView {
    let clipView = UIView()
    let skyView = UIImageView(image: R.image.fwSkyCard())
    let geometryView: FWSolarGeometryView
    let scrim = CAGradientLayer()
    let rim = FWLitRimLayer()
    private let glow = CAGradientLayer()
    private let effects: FWEffects
    private var observation: NSObjectProtocol?

    /// The badge's centre in this view's coordinates: the sky's sun and the geometry sit behind it.
    var sunCenter: CGPoint? {
        didSet { if sunCenter != oldValue { setNeedsLayout() } }
    }

    /// Where the card's text begins, in this view's coordinates: the scrim is at full strength from here down.
    var textTop: CGFloat? {
        didSet { if textTop != oldValue { setNeedsLayout() } }
    }

    /// Scroll drift of the sky, in points (clamped to a few points).
    var drift: CGFloat = 0 {
        didSet { if drift != oldValue { setNeedsLayout() } }
    }

    static let maxDrift: CGFloat = 10

    init(effects: FWEffects = .shared) {
        self.effects = effects
        geometryView = FWSolarGeometryView(effects: effects)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        layer.shadowColor = FWFeel.plum.cgColor
        layer.shadowOpacity = 0.9
        layer.shadowRadius = 22
        layer.shadowOffset = CGSize(width: 0, height: 12)
        clipView.clipsToBounds = true
        clipView.layer.cornerRadius = FWSunlit.Radius.card
        clipView.layer.cornerCurve = .continuous
        clipView.backgroundColor = FWSunlit.Palette.background
        addSubview(clipView)
        skyView.contentMode = .scaleToFill
        clipView.addSubview(skyView)
        geometryView.radiusFraction = 1
        geometryView.groupOpacity = ["ring": 0.9, "ticks": 0.8, "hexagram": 0.32, "lattice": 0.22, "ray": 0.22, "stars": 0.7]
        clipView.addSubview(geometryView)
        scrim.startPoint = CGPoint(x: 0.5, y: 0)
        scrim.endPoint = CGPoint(x: 0.5, y: 1)
        clipView.layer.addSublayer(scrim)
        glow.type = .radial
        // A radial gradient's radius runs from its start point to its end point: here, the frame's edge.
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.colors = [FWSunlit.Palette.sun.withAlphaComponent(0.42), FWSunlit.Palette.sun.withAlphaComponent(0)].map(\.cgColor)
        glow.locations = [0, 1]
        glow.opacity = 0
        clipView.layer.addSublayer(glow)
        rim.cornerRadiusValue = FWSunlit.Radius.card
        layer.addSublayer(rim)
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.updateMotion() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observation { effects.notificationCenter.removeObserver(observation) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateMotion()
    }

    private func updateMotion() {
        geometryView.setTurning(window != nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clipView.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: FWSunlit.Radius.card).cgPath
        let sun = sunCenter ?? CGPoint(x: bounds.midX, y: min(bounds.height * 0.3, 60))
        skyView.frame = Self.skyFrame(in: bounds, imageSize: skyView.image?.size ?? CGSize(width: 1200, height: 675), sun: sun, drift: drift)
        let side = max(bounds.width, bounds.height) * 1.1
        geometryView.frame = CGRect(x: sun.x - side / 2, y: sun.y - side / 2, width: side, height: side)
        geometryView.radiusFraction = min(1, (min(bounds.width, bounds.height) * 0.52) / (side / 2))
        scrim.frame = bounds
        let textStart = min(max(0.2, (textTop ?? bounds.height * 0.42) / max(1, bounds.height)), 0.9)
        scrim.colors = [FWFeel.scrimTop, FWFeel.scrimText, FWFeel.scrimText, FWFeel.scrimBottom].map {
            FWSunlit.Palette.background.withAlphaComponent($0).cgColor
        }
        scrim.locations = [0, NSNumber(value: Double(max(0, textStart - 0.12))), NSNumber(value: Double(textStart)), 1]
        let reach = max(bounds.width, bounds.height) * 0.75
        glow.frame = CGRect(x: sun.x - reach, y: sun.y - reach, width: reach * 2, height: reach * 2)
        rim.frame = bounds
        CATransaction.commit()
    }

    /// Aspect-fill of the sky with its sun placed at `sun` as far as covering the card allows, shifted by the drift.
    static func skyFrame(in bounds: CGRect, imageSize: CGSize, sun: CGPoint, drift: CGFloat) -> CGRect {
        guard bounds.width > 0, bounds.height > 0, imageSize.width > 0, imageSize.height > 0 else { return bounds }
        // A little larger than cover, so the drift never shows an edge.
        let scale = max(bounds.width / imageSize.width, (bounds.height + 2 * maxDrift) / imageSize.height) * 1.08
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let clamped = max(-maxDrift, min(maxDrift, drift))
        let idealX = sun.x - FWFeel.skySun.x * size.width
        let idealY = sun.y - FWFeel.skySun.y * size.height + clamped
        let x = min(bounds.minX, max(bounds.maxX - size.width, idealX))
        let y = min(bounds.minY, max(bounds.maxY - size.height, idealY))
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// The gold pulse when tokens arrive: the badge's light swells over the card and the rim brightens, then both
    /// settle. Reduced motion keeps a short fade.
    func pulse() {
        let total: TimeInterval
        switch FWMotionPolicy.current(effects: effects).style(for: .syncFinished) {
        case .full: total = 1.1
        case .crossfade: total = FWSunlit.Motion.maxCrossfade * 2
        case .none: return
        }
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0, 1, 0]
        flash.keyTimes = [0, 0.25, 1]
        flash.duration = total
        flash.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeInEaseOut)]
        glow.add(flash, forKey: "fw.pulse")
        rim.flash(duration: total)
    }
}

/// Two very soft glows, pink and ember, drifting over the ink behind the wallet home, one cycle a minute. Each stays
/// under 18 % at its centre. Reduced motion holds them still.
final class FWAuroraView: UIView {
    private let pink = CAGradientLayer()
    private let ember = CAGradientLayer()
    private let effects: FWEffects
    private var observation: NSObjectProtocol?

    init(effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        for (layer, color) in [(pink, FWSunlit.Palette.brand), (ember, FWFeel.ember)] {
            layer.type = .radial
            layer.startPoint = CGPoint(x: 0.5, y: 0.5)
            layer.endPoint = CGPoint(x: 1, y: 1)
            layer.colors = [color.withAlphaComponent(FWFeel.auroraAlpha), color.withAlphaComponent(0)].map(\.cgColor)
            layer.locations = [0, 1]
            self.layer.addSublayer(layer)
        }
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.updateDrift() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observation { effects.notificationCenter.removeObserver(observation) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = max(bounds.width, bounds.height) * 0.9
        pink.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        ember.bounds = CGRect(x: 0, y: 0, width: side * 0.85, height: side * 0.85)
        pink.position = CGPoint(x: bounds.width * 0.2, y: bounds.height * 0.18)
        ember.position = CGPoint(x: bounds.width * 0.85, y: bounds.height * 0.55)
        CATransaction.commit()
        updateDrift()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDrift()
    }

    private func updateDrift() {
        pink.removeAnimation(forKey: "fw.aurora")
        ember.removeAnimation(forKey: "fw.aurora")
        guard window != nil, bounds.width > 0, !FWMotionPolicy.current(effects: effects).isRestricted else { return }
        pink.add(Self.drift(from: pink.position, by: CGVector(dx: bounds.width * 0.35, dy: bounds.height * 0.12)), forKey: "fw.aurora")
        ember.add(Self.drift(from: ember.position, by: CGVector(dx: -bounds.width * 0.4, dy: -bounds.height * 0.1)), forKey: "fw.aurora")
    }

    private static func drift(from start: CGPoint, by offset: CGVector) -> CAAnimation {
        let path = UIBezierPath()
        path.move(to: start)
        path.addCurve(
            to: CGPoint(x: start.x + offset.dx, y: start.y + offset.dy),
            controlPoint1: CGPoint(x: start.x + offset.dx * 0.2, y: start.y + offset.dy * 1.6),
            controlPoint2: CGPoint(x: start.x + offset.dx * 0.8, y: start.y - offset.dy * 0.6)
        )
        let move = CAKeyframeAnimation(keyPath: "position")
        move.path = path.cgPath
        move.duration = FWFeel.auroraCycle / 2
        move.autoreverses = true
        move.repeatCount = .infinity
        move.calculationMode = .paced
        move.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut)]
        move.isRemovedOnCompletion = false
        return move
    }
}
