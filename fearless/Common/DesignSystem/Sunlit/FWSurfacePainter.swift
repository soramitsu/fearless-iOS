import UIKit

/// Paints one sun-lit surface into a host layer: the key-light shadow pair, the fill, the inner shadow of
/// a well, the rim that catches the key light and the sun bounce, and the emissive glow. Every shadow has
/// an explicit path, so the paint stays cheap in long lists. The host owns geometry and state.
final class FWSurfacePainter {
    struct State: Equatable {
        var elevation: FWSunlit.Elevation = .raised2
        /// Surface colour. Nil paints `bg`, or `bgDeep` for inset wells and pressed controls.
        var fill: UIColor?
        /// Sun bounce on the top rim, 0...0.35 (`FWSunlit.Light.sunRim`).
        var sunRim: CGFloat = 0
        var pressed = false
        var focused = false
        var error = false
        /// Interactive controls keep a 1 pt edge in every mode (spec section 3, accessibility).
        var interactive = false
        /// Calm surfaces and Reduced effects paint without shadows or glow.
        var reduced = false
        /// High contrast swaps shadows for a solid white 40 % stroke.
        var highContrast = false
    }

    let keyShadow = CALayer()
    let highlightShadow = CALayer()
    let fill = CAShapeLayer()
    let emissive = CAGradientLayer()
    let innerShadow = CAShapeLayer()
    let rim = CAGradientLayer()
    let ring = CAShapeLayer()
    private let emissiveMask = CAShapeLayer()
    private let innerShadowMask = CAShapeLayer()
    private let rimMask = CAShapeLayer()

    private(set) var state = State()
    private var shapePath: CGPath?

    /// Bottom to top. Hosts insert them below their content.
    var layers: [CALayer] {
        [keyShadow, highlightShadow, fill, emissive, innerShadow, rim, ring]
    }

    init() {
        for layer in [keyShadow, highlightShadow] {
            layer.backgroundColor = UIColor.clear.cgColor
            layer.masksToBounds = false
        }
        emissive.colors = [FWSunlit.Palette.gradientStart, FWSunlit.Palette.gradientEnd].map(\.cgColor)
        emissive.startPoint = .zero
        emissive.endPoint = CGPoint(x: 1, y: 1)
        emissive.mask = emissiveMask
        emissiveMask.fillColor = UIColor.black.cgColor
        innerShadow.fillColor = UIColor.black.cgColor
        innerShadow.fillRule = .evenOdd
        innerShadow.mask = innerShadowMask
        innerShadowMask.fillColor = UIColor.black.cgColor
        rim.mask = rimMask
        rimMask.fillColor = nil
        rimMask.strokeColor = UIColor.black.cgColor
        rimMask.lineWidth = FWSunlit.Rim.width
        ring.fillColor = nil
        layers.forEach { $0.contentsScale = UIScreen.main.scale }
    }

    /// Inserts the surface at the bottom of `host`, under any existing sublayer.
    func install(in host: CALayer) {
        for (index, layer) in layers.enumerated() {
            host.insertSublayer(layer, at: UInt32(index))
        }
    }

    func layout(path: UIBezierPath, bounds: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let cgPath = path.cgPath
        shapePath = cgPath
        for layer in layers {
            layer.frame = bounds
        }
        keyShadow.shadowPath = cgPath
        highlightShadow.shadowPath = cgPath
        fill.path = cgPath
        emissiveMask.frame = bounds
        emissiveMask.path = cgPath
        // The well's inner shadow is cast by everything outside the shape. The inner contour runs the other
        // way so the non-zero shadow path leaves the shape itself open.
        let outside = UIBezierPath(rect: bounds.insetBy(dx: -24, dy: -24))
        outside.append(path.reversing())
        innerShadow.path = outside.cgPath
        innerShadow.shadowPath = outside.cgPath
        innerShadowMask.frame = bounds
        innerShadowMask.path = cgPath
        rimMask.frame = bounds
        rimMask.path = Self.inset(path: path, by: FWSunlit.Rim.width / 2)
        applyRing(path: path)
    }

    /// Paints `state`. A non-zero duration animates the change (press feedback); zero applies it at once.
    func apply(_ state: State, duration: TimeInterval = 0, timing: CAMediaTimingFunction? = nil) {
        self.state = state
        CATransaction.begin()
        if duration > 0 {
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(timing ?? CAMediaTimingFunction(name: .easeOut))
        } else {
            CATransaction.setDisableActions(true)
        }
        defer { CATransaction.commit() }
        paintShadows(state)
        paintFill(state)
        paintInnerShadow(state)
        paintRim(state)
        paintRing(state)
    }

    // MARK: - Paint

    private var showsShadows: Bool { !state.reduced && !state.highContrast }

    private func paintShadows(_ state: State) {
        let raised = !state.pressed ? FWSunlit.Shadows.pair(for: state.elevation) : nil
        if state.elevation == .emissive, showsShadows {
            configure(keyShadow, FWSunlit.Shadows.emissiveGlow, opacityFactor: state.pressed ? 0.45 : 1)
            highlightShadow.shadowOpacity = 0
            highlightShadow.isHidden = true
            keyShadow.isHidden = false
        } else if let raised = raised, showsShadows {
            configure(keyShadow, raised.key)
            configure(highlightShadow, raised.highlight)
            keyShadow.isHidden = false
            highlightShadow.isHidden = false
        } else {
            keyShadow.shadowOpacity = 0
            highlightShadow.shadowOpacity = 0
            keyShadow.isHidden = true
            highlightShadow.isHidden = true
        }
    }

    private func configure(_ layer: CALayer, _ shadow: FWSunlit.Shadow, opacityFactor: Float = 1) {
        layer.shadowColor = shadow.color.cgColor
        layer.shadowOffset = shadow.offset
        layer.shadowRadius = shadow.layerRadius
        layer.shadowOpacity = shadow.opacity * opacityFactor
    }

    private func paintFill(_ state: State) {
        let sunken = state.elevation == .inset || (state.pressed && state.elevation != .emissive)
        let base = state.fill ?? (sunken ? FWSunlit.Palette.backgroundDeep : FWSunlit.Palette.background)
        let color = sunken && state.fill != nil && state.elevation != .inset ? FWSunlit.Palette.backgroundDeep : base
        fill.fillColor = state.elevation == .flat && state.fill == nil ? UIColor.clear.cgColor : color.cgColor
        emissive.isHidden = state.elevation != .emissive
        emissive.opacity = state.pressed ? 0.86 : 1
    }

    private func paintInnerShadow(_ state: State) {
        let sunken = state.elevation == .inset || state.pressed
        let visible = sunken && showsShadows && state.elevation != .flat
        let shadow = FWSunlit.Shadows.insetDark
        innerShadow.shadowColor = shadow.color.cgColor
        innerShadow.shadowOffset = shadow.offset
        innerShadow.shadowRadius = shadow.layerRadius
        innerShadow.shadowOpacity = visible ? shadow.opacity : 0
        innerShadow.isHidden = !visible
    }

    private func paintRim(_ state: State) {
        let sunken = state.elevation == .inset || state.pressed
        let rimAlpha = FWSunlit.Rim.keyLightAlpha
        let colors: [UIColor]
        let locations: [NSNumber]
        switch state.elevation {
        case .emissive:
            colors = [UIColor(white: 1, alpha: FWSunlit.Rim.emissiveHighlightAlpha), UIColor(white: 1, alpha: 0)]
            locations = [0, 0.3]
        case _ where sunken:
            // A well catches the key light on its lower lip: the light inner edge sits bottom-right.
            colors = [UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 0.02), UIColor(white: 1, alpha: 0.07)]
            locations = [0, 0.55, 1]
        case .flat:
            colors = [UIColor(white: 1, alpha: state.interactive ? rimAlpha : 0), UIColor(white: 1, alpha: 0)]
            locations = [0, 0.7]
        case .raised1, .raised2, .inset:
            let sun = min(max(state.sunRim, 0), FWSunlit.Light.maxSunRim)
            let top = sun > 0
                ? FWSunlit.Palette.sunRim.withAlphaComponent(max(sun, rimAlpha))
                : UIColor(white: 1, alpha: rimAlpha)
            colors = [top, UIColor(white: 1, alpha: FWSunlit.Rim.keyLightMidAlpha), UIColor(white: 1, alpha: 0)]
            locations = [0, 0.3, 0.7]
        }
        rim.colors = colors.map(\.cgColor)
        rim.locations = locations
        rim.startPoint = CGPoint(x: 0.5, y: 0)
        rim.endPoint = CGPoint(x: 0.5, y: 1)
        rim.isHidden = state.highContrast || (state.elevation == .flat && !state.interactive)
    }

    private func paintRing(_ state: State) {
        let color: UIColor?
        if state.error {
            color = FWSunlit.Palette.danger
        } else if state.focused {
            color = FWSunlit.Palette.brand
        } else if state.highContrast, state.elevation != .flat || state.interactive {
            color = UIColor(white: 1, alpha: FWSunlit.Rim.highContrastAlpha)
        } else if state.reduced, state.elevation == .inset || state.interactive {
            color = UIColor(white: 1, alpha: 0.08)
        } else {
            color = nil
        }
        let width: CGFloat = state.error || state.focused ? 2 : 1
        if ring.lineWidth != width {
            ring.lineWidth = width
            if let shapePath = shapePath {
                applyRing(path: UIBezierPath(cgPath: shapePath))
            }
        }
        ring.strokeColor = color?.cgColor
        ring.isHidden = color == nil
    }

    private func applyRing(path: UIBezierPath) {
        ring.path = Self.inset(path: path, by: ring.lineWidth / 2)
    }

    /// The shape scaled inwards so a centred stroke of twice `amount` stays inside the shape.
    static func inset(path: UIBezierPath, by amount: CGFloat) -> CGPath {
        let box = path.bounds
        guard box.width > amount * 2, box.height > amount * 2 else { return path.cgPath }
        let target = box.insetBy(dx: amount, dy: amount)
        var transform = CGAffineTransform(translationX: target.minX, y: target.minY)
            .scaledBy(x: target.width / box.width, y: target.height / box.height)
            .translatedBy(x: -box.minX, y: -box.minY)
        return path.cgPath.copy(using: &transform) ?? path.cgPath
    }
}
