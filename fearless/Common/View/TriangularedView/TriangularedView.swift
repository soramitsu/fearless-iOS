import UIKit
import SoraUI

public struct TriangularedCorners: OptionSet {
    public typealias RawValue = UInt8

    static let none: TriangularedCorners = []
    static let topLeft = TriangularedCorners(rawValue: 1)
    static let bottomRight = TriangularedCorners(rawValue: 2)

    public var rawValue: TriangularedCorners.RawValue

    public init(rawValue: TriangularedCorners.RawValue) {
        self.rawValue = rawValue
    }
}

/**
    Subclass of ShadowShapeView that draws the app's surfaces. Since the 2026-11 sun-lit redesign the shape is a
    continuous rounded rectangle (18 pt for controls, 22 pt for cards) and opaque dark fills are painted as
    sun-lit neumorphic surfaces by `FWSurfacePainter`. `sideLength` and `cornerCut` are kept for source
    compatibility and no longer cut corners.
 */

open class TriangularedView: ShadowShapeView {
    /// Kept for source compatibility; the sun-lit shape has no cut corners. Defaults `10.0`.
    @IBInspectable
    open var sideLength: CGFloat = 10.0 {
        didSet {
            applyPath()
        }
    }

    /// Kept for source compatibility; the sun-lit shape has no cut corners.
    open var cornerCut: TriangularedCorners = [.topLeft, .bottomRight] {
        didSet {
            applyPath()
        }
    }

    var gradientBorderColors: [UIColor] = []
    var gradientBorderStartPoint = CGPoint(x: 0.0, y: 0.5)
    var gradientBorderEndPoint = CGPoint(x: 1.0, y: 0.5)

    /// Corner radius. Nil uses 18 pt up to 64 pt of height, 22 pt above, never more than half the height.
    var fwCornerRadius: CGFloat? {
        didSet {
            applyPath()
            setNeedsLayout()
        }
    }

    /// Sun-lit elevation. Nil paints opaque dark fills as Raised-1 and leaves other fills as they are;
    /// `.flat` keeps the plain fill and stroke (masks, overlays).
    var fwElevation: FWSunlit.Elevation? {
        didSet { applyLayerStyle() }
    }

    /// Sun bounce on the top rim (`FWSunlit.Light.sunRim`).
    var fwSunRim: CGFloat = 0 {
        didSet { applyLayerStyle() }
    }

    /// Interactive surfaces keep a 1 pt rim in every mode.
    var fwInteractive = false {
        didSet { applyLayerStyle() }
    }

    var fwFocused = false {
        didSet { applyLayerStyle() }
    }

    var fwError = false {
        didSet { applyLayerStyle() }
    }

    private var surfacePainter: FWSurfacePainter?
    private var effectsObservation: NSObjectProtocol?
    private var paintedHighlight: Bool?

    deinit {
        if let effectsObservation {
            FWEffects.shared.notificationCenter.removeObserver(effectsObservation)
        }
    }

    // MARK: Overriden methods

    override open var shapePath: UIBezierPath {
        UIBezierPath(roundedRect: bounds, cornerRadius: resolvedCornerRadius)
    }

    var resolvedCornerRadius: CGFloat {
        let height = bounds.height
        let preferred = fwCornerRadius ?? (height <= 64 ? FWSunlit.Radius.button : FWSunlit.Radius.card)
        return max(0, min(preferred, height / 2, bounds.width / 2))
    }

    /// The elevation the sun-lit painter uses, or nil when the plain fill and stroke paint the view.
    var resolvedElevation: FWSunlit.Elevation? {
        if let fwElevation = fwElevation {
            return fwElevation == .flat ? nil : fwElevation
        }
        return Self.automaticElevation(for: isHighlighted ? highlightedFillColor : fillColor)
    }

    /// Opaque fills in the dark surface family (luminance above black and below 3 %) read as Raised-1.
    static func automaticElevation(for fill: UIColor) -> FWSunlit.Elevation? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard fill.getRed(&red, green: &green, blue: &blue, alpha: &alpha), alpha > 0.99 else { return nil }
        let luminance = FWSunlit.luminance(fill)
        return luminance > 0.000_5 && luminance < 0.03 ? .raised1 : nil
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        surfacePainter?.layout(path: shapePath, bounds: bounds)
    }

    override open func applyLayerStyle() {
        super.applyLayerStyle()
        applySunlitPaint()
    }

    override open func animateLayerStyle(to highlighted: Bool) {
        guard resolvedElevation == nil else { return }
        super.animateLayerStyle(to: highlighted)
    }

    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applySunlitPaint()
    }

    private func applySunlitPaint() {
        guard let layer = layer as? CAShapeLayer else { return }
        guard let elevation = resolvedElevation else {
            surfacePainter?.layers.forEach { $0.isHidden = true }
            return
        }
        let painter = surfacePainter ?? makePainter()
        let effects = FWEffects.shared
        let fill = isHighlighted ? highlightedFillColor : fillColor
        // Only a highlight change animates: 90 ms into the press, 160 ms back out (spec section 4).
        let pressChanged = paintedHighlight.map { $0 != isHighlighted } ?? false
        paintedHighlight = isHighlighted
        let duration = pressChanged ? (isHighlighted ? FWSunlit.Motion.pressIn : FWSunlit.Motion.pressOut) : 0
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.clear.cgColor
        layer.shadowOpacity = 0
        layer.shouldRasterize = false
        painter.layers.forEach { $0.isHidden = false }
        painter.apply(FWSurfacePainter.State(
            elevation: elevation,
            fill: elevation == .emissive || elevation == .inset || fill.cgColor.alpha < 0.99 ? nil : fill,
            sunRim: fwSunRim,
            pressed: isHighlighted && elevation != .inset,
            // An inset well (an input) shows its highlight as the brand focus ring.
            focused: fwFocused || (isHighlighted && elevation == .inset),
            error: fwError,
            interactive: fwInteractive,
            reduced: effects.paintReduced(),
            highContrast: effects.highContrast || traitCollection.accessibilityContrast == .high
        ), duration: duration)
    }

    private func makePainter() -> FWSurfacePainter {
        let painter = FWSurfacePainter()
        painter.install(in: layer)
        painter.layout(path: shapePath, bounds: bounds)
        surfacePainter = painter
        effectsObservation = FWEffects.shared.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: FWEffects.shared, queue: .main
        ) { [weak self] _ in self?.applySunlitPaint() }
        return painter
    }
}

extension TriangularedView {
    private static let kLayerNameGradientBorder = "GradientBorderLayer"

    func setGradientBorder(highlighted: Bool, animated: Bool) {
        let border = gradientBorderLayer()
        border.frame = bounds
        border.startPoint = gradientBorderStartPoint
        border.endPoint = gradientBorderEndPoint

        let mask = CAShapeLayer()
        mask.path = shapePath.cgPath
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.white.cgColor
        mask.lineWidth = strokeWidth
        border.mask = mask
        border.colors = highlighted ? gradientBorderColors.map { $0.cgColor } : [UIColor.clear].map { $0.cgColor }

        if animated {
            clearGradientAnimation()
            animateGradientColor(border: border, to: highlighted)
        }
    }

    private func gradientBorderLayer() -> CAGradientLayer {
        let borderLayers = layer.sublayers?.filter { $0.name == Self.kLayerNameGradientBorder }
        if borderLayers?.count ?? 0 > 1 {
            fatalError()
        }
        guard let border = borderLayers?.first as? CAGradientLayer else {
            let newBorder = CAGradientLayer()
            newBorder.name = Self.kLayerNameGradientBorder
            layer.addSublayer(newBorder)
            return newBorder
        }
        return border
    }

    private func animateGradientColor(border: CAGradientLayer, to highlighted: Bool) {
        let animation = CABasicAnimation(keyPath: "strokeColor")
        animation.fromValue = !highlighted ? gradientBorderColors.map { $0.cgColor } : [UIColor.clear].map { $0.cgColor }
        animation.toValue = highlighted ? gradientBorderColors.map { $0.cgColor } : [UIColor.clear].map { $0.cgColor }
        animation.duration = highlightableAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        border.add(animation, forKey: "gradientAnimationKay")
    }

    private func clearGradientAnimation() {
        if let layer = self.layer as? CAGradientLayer {
            layer.removeAnimation(forKey: "gradientAnimationKay")
        }
    }
}

extension TriangularedView {
    /// Inputs sit in an inset well; their highlight shows as the brand focus ring (sun-lit redesign).
    func fwMakeInsetWell() {
        fwElevation = .inset
        fwInteractive = true
    }
}
