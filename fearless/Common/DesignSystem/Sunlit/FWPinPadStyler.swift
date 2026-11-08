import SnapKit
import SoraUI
import UIKit

/// Sun-lit paint for SoraUI's `PinView`: raised round keys that sink when pressed, PIN dots that sit in small
/// wells and fill from the key-light side, and a short damped shake for a wrong PIN (spec sections 3 and 4).
/// It only decorates: input, the delegate, accessibility identifiers and the lockout logic stay untouched.
final class FWPinPadStyler {
    private weak var pinView: PinView?
    private let effects: FWEffects
    private var dots: FWPinDotsView?
    private var keySurfaces: [ObjectIdentifier: FWNeuView] = [:]

    init(pinView: PinView, effects: FWEffects = .shared) {
        self.pinView = pinView
        self.effects = effects
    }

    /// Paints the keys and dots. Call after the PIN view's mode and fonts are set, and again after relayout.
    func apply(textColor: UIColor = FWSunlit.Palette.textPrimary) {
        guard let pinView = pinView, let numpad = pinView.numpadView else { return }
        numpad.fillColor = .clear
        numpad.highlightedFillColor = .clear
        numpad.titleColor = textColor
        numpad.highlightedTitleColor = textColor
        numpad.shadowOpacity = 0
        for key in numpad.subviews.compactMap({ $0 as? RoundedButton }) {
            decorate(key: key)
        }
        installDots(in: pinView)
        applyWrongPinMotion(to: pinView)
    }

    /// SoraUI's own wrong-PIN feedback (vibration plus a spring of the dots) tuned to the spec's
    /// 2 × 6 pt in 300 ms; Reduced motion keeps the vibration and drops the movement.
    private func applyWrongPinMotion(to pinView: PinView) {
        let style = FWMotionPolicy.current(effects: effects).style(for: .wrongPin)
        pinView.errorAnimationAmplitude = style == .full(style.duration) ? FWSunlit.Motion.shakeDistance : 0
        pinView.errorAnimationDuration = CGFloat(FWSunlit.Motion.shake)
        pinView.errorAnimationDamping = 0.18
        pinView.errorAnimationInitialVelocity = 0
    }

    private func decorate(key: RoundedButton) {
        guard let title = key.imageWithTitleView?.title, title.count == 1, title.first?.isWholeNumber == true else {
            return
        }
        key.roundedBackgroundView?.fillColor = .clear
        key.roundedBackgroundView?.highlightedFillColor = .clear
        key.roundedBackgroundView?.shadowOpacity = 0
        let id = ObjectIdentifier(key)
        guard keySurfaces[id] == nil else { return }
        let surface = FWNeuView(effects: effects)
        surface.style = .raised
        surface.isInteractive = true
        surface.isUserInteractionEnabled = false
        surface.shape = { UIBezierPath(ovalIn: $0) }
        surface.frame = key.bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        key.insertSubview(surface, at: 0)
        keySurfaces[id] = surface
        key.addTarget(self, action: #selector(keyDown(_:)), for: [.touchDown, .touchDragEnter])
        key.addTarget(self, action: #selector(keyUp(_:)), for: FWPress.releaseEvents)
    }

    /// Sun rim for each key from its distance to the sun (the PIN screen's badge).
    func applySunRim(sunCenter: CGPoint, in coordinateSpace: UIView) {
        let width = coordinateSpace.bounds.width
        for (_, surface) in keySurfaces {
            let frame = surface.convert(surface.bounds, to: coordinateSpace)
            surface.sunRim = FWSunlit.Light.sunRim(for: frame, sunCenter: sunCenter, screenWidth: width)
        }
    }

    @objc private func keyDown(_ key: RoundedButton) {
        guard let surface = keySurfaces[ObjectIdentifier(key)] else { return }
        FWPress.apply(true, to: key, surface: surface, effects: effects)
    }

    @objc private func keyUp(_ key: RoundedButton) {
        guard let surface = keySurfaces[ObjectIdentifier(key)] else { return }
        FWPress.apply(false, to: key, surface: surface, effects: effects)
    }

    private func installDots(in pinView: PinView) {
        guard dots == nil, let fields = pinView.securedCharacterFieldsView else { return }
        fields.fillColor = .clear
        fields.strokeColor = .clear
        let overlay = FWPinDotsView(fields: fields, effects: effects)
        overlay.frame = fields.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        fields.addSubview(overlay)
        dots = overlay
    }
}

/// The PIN dots: small inset wells that fill with the brand glow from the top-left (the key light). They
/// follow the PIN view's own entered count, whatever changed it (keys, resets, lockouts, confirmation).
final class FWPinDotsView: UIView {
    private weak var fields: SecuredCharacterFieldsView?
    private let effects: FWEffects
    private var wells: [FWNeuView] = []
    private var fills: [CAGradientLayer] = []
    private var filled = 0
    private var displayLink: CADisplayLink?

    init(fields: SecuredCharacterFieldsView, effects: FWEffects) {
        self.fields = fields
        self.effects = effects
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    /// While on screen, the dots read the field's count each frame (an integer compare) so that no input path
    /// of the PIN view can leave them stale.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil
        guard window != nil else { return }
        let link = CADisplayLink(target: FWWeakTarget(self), selector: #selector(FWWeakTarget.tick))
        link.preferredFramesPerSecond = 30
        link.add(to: .main, forMode: .common)
        displayLink = link
        setFilled(fields?.characters.count ?? 0, animated: false)
    }

    fileprivate func followFields() {
        guard let count = fields?.characters.count, count != filled else { return }
        setFilled(count, animated: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let fields = fields else { return }
        let count = fields.numberOfCharacters
        if wells.count != count { rebuild(count: count) }
        let side = max(14, fields.fieldRadius * 2 + 4)
        let size = fields.fieldSize
        let originX = bounds.midX - fields.intrinsicContentSize.width / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for index in 0 ..< count {
            let centerX = originX + CGFloat(index) * (size.width + fields.fieldSpacing) + size.width / 2
            let frame = CGRect(x: centerX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
            wells[index].frame = frame
            fills[index].bounds = CGRect(origin: .zero, size: frame.size)
            fills[index].position = CGPoint(x: frame.minX + side * 0.3, y: frame.minY + side * 0.3)
            fills[index].cornerRadius = side / 2
        }
        CATransaction.commit()
    }

    private func rebuild(count: Int) {
        wells.forEach { $0.removeFromSuperview() }
        fills.forEach { $0.removeFromSuperlayer() }
        wells = (0 ..< count).map { _ in
            let well = FWNeuView(effects: effects)
            well.style = .inset
            well.shape = { UIBezierPath(ovalIn: $0) }
            well.isUserInteractionEnabled = false
            addSubview(well)
            return well
        }
        fills = (0 ..< count).map { _ in makeFill() }
        filled = 0
    }

    private func makeFill() -> CAGradientLayer {
        let fill = CAGradientLayer()
        fill.type = .radial
        let highlight = FWSunlit.color(0xFF5AA8)
        fill.colors = [highlight, FWSunlit.Palette.brand, FWSunlit.Palette.gradientEnd].map(\.cgColor)
        fill.locations = [0, 0.55, 1]
        fill.startPoint = CGPoint(x: 0.35, y: 0.35)
        fill.endPoint = CGPoint(x: 1.1, y: 1.1)
        fill.anchorPoint = CGPoint(x: 0.3, y: 0.3)
        fill.shadowColor = FWSunlit.Palette.brand.cgColor
        fill.shadowRadius = 5
        fill.shadowOpacity = 0.7
        fill.shadowOffset = .zero
        fill.opacity = 0
        layer.addSublayer(fill)
        return fill
    }

    func setFilled(_ count: Int, animated: Bool) {
        layoutIfNeeded()
        let style = FWMotionPolicy.current(effects: effects).style(for: .pinDigit)
        for (index, fill) in fills.enumerated() {
            let isFilled = index < count
            let wasFilled = index < filled
            guard isFilled != wasFilled || !animated else { continue }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            fill.opacity = isFilled ? 1 : 0
            fill.transform = CATransform3DIdentity
            CATransaction.commit()
            guard animated, isFilled, !wasFilled, style.animates else { continue }
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = style == .full(style.duration) ? 0.2 : 1
            grow.toValue = 1
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            let group = CAAnimationGroup()
            group.animations = [grow, fade]
            group.duration = style.duration
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fill.add(group, forKey: "fw.fill")
        }
        filled = count
    }
}

/// Breaks the display link's strong reference to its target.
private final class FWWeakTarget: NSObject {
    weak var dots: FWPinDotsView?

    init(_ dots: FWPinDotsView) {
        self.dots = dots
    }

    @objc func tick() {
        dots?.followFields()
    }
}

/// A PIN screen's sun-lit scene: the page light, the winged sun at full span that lights it, and the styled
/// keypad. The screen adds `wingsRow` to its content; the row keeps the page light and the key rims on its sun.
final class FWPinScreenSunlit {
    let styler: FWPinPadStyler
    let wings = FWWingsView()
    private let background = FWSunlitBackgroundView()
    private(set) lazy var wingsRow: UIView = FWLayoutReportingView { [weak self] in self?.lightScene() }

    init(pinView: PinView, effects: FWEffects = .shared) {
        styler = FWPinPadStyler(pinView: pinView, effects: effects)
        wings.isAccessibilityElement = false
        wingsRow.addSubview(wings)
        wings.snp.makeConstraints { make in
            wings.makeWideConstraints(make)
            make.top.bottom.equalToSuperview()
        }
    }

    /// Adds the wings row to `content` and the page light behind everything in `rootView`.
    func attach(to content: UIStackView, in rootView: UIView) {
        installLight(in: rootView)
        content.insertArrangedSubview(wingsRow, at: 0)
    }

    /// The page light behind everything in `rootView`, for screens that place `wingsRow` themselves.
    func installLight(in rootView: UIView) {
        rootView.backgroundColor = FWSunlit.Palette.background
        rootView.insertSubview(background, at: 0)
        background.frame = rootView.bounds
        background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    private func lightScene() {
        guard let root = background.superview else { return }
        let sunCenter = wings.convert(CGPoint(x: wings.bounds.midX, y: wings.bounds.midY), to: root)
        background.sunCenter = sunCenter
        styler.applySunRim(sunCenter: sunCenter, in: root)
    }
}

/// A plain container that reports each layout pass.
final class FWLayoutReportingView: UIView {
    private let onLayout: () -> Void

    init(onLayout: @escaping () -> Void) {
        self.onLayout = onLayout
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout()
    }
}
