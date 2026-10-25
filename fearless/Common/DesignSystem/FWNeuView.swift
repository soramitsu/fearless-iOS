import UIKit

/// A control-sized raised/inset well. Repeated PIN keys should use the Calm bevel, not shadow layers.
final class FWNeuView: UIView {
    enum Style { case raised, inset }

    var style: Style = .raised {
        didSet { applyStyle(); setNeedsLayout() }
    }

    var calm = false {
        didSet { applyStyle() }
    }

    var controlFocused = false {
        didSet { applyStyle(); setNeedsLayout() }
    }

    var hasError = false {
        didSet { applyStyle(); setNeedsLayout() }
    }

    var shape: (CGRect) -> UIBezierPath = { UIBezierPath(roundedRect: $0, cornerRadius: FWTokens.Radius.s) } {
        didSet { setNeedsLayout() }
    }

    private let effects: FWEffects
    private var observation: NSObjectProtocol?
    private let dark = CALayer()
    private let light = CALayer()
    private let fill = CAShapeLayer()
    private let insetShadow = CAShapeLayer()
    private let insetMask = CAShapeLayer()
    private let bevel = CAGradientLayer()
    private let bevelMask = CAShapeLayer()
    private let rim = CAShapeLayer()

    init(frame: CGRect = .zero, effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = false
        [dark, light, fill, insetShadow, bevel, rim].forEach(layer.addSublayer)
        dark.shadowColor = UIColor.black.cgColor
        dark.shadowRadius = 7
        dark.shadowOffset = CGSize(width: 6, height: 6)
        light.shadowColor = UIColor.white.cgColor
        light.shadowRadius = 5
        light.shadowOffset = CGSize(width: -4, height: -4)
        insetShadow.fillColor = UIColor.black.cgColor
        insetShadow.fillRule = .evenOdd
        insetShadow.shadowColor = UIColor.black.cgColor
        insetShadow.shadowRadius = 3
        insetShadow.shadowOffset = CGSize(width: 2, height: 2)
        insetShadow.mask = insetMask
        insetMask.fillColor = UIColor.black.cgColor
        bevel.startPoint = .zero
        bevel.endPoint = CGPoint(x: 1, y: 1)
        bevel.colors = [UIColor(white: 1, alpha: 0.06), .clear, UIColor(white: 0, alpha: 0.2)].map(\.cgColor)
        bevel.locations = [0, 0.5, 1]
        bevel.mask = bevelMask
        bevelMask.fillColor = UIColor.black.cgColor
        rim.fillColor = nil
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.applyStyle() }
        applyStyle()
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

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let path = shape(bounds)
        dark.frame = bounds
        light.frame = bounds
        dark.shadowPath = path.cgPath
        light.shadowPath = path.cgPath
        fill.path = path.cgPath
        insetShadow.frame = bounds
        insetMask.frame = bounds
        insetMask.path = path.cgPath
        let outside = UIBezierPath(rect: bounds.insetBy(dx: -20, dy: -20))
        outside.append(path)
        outside.usesEvenOddFillRule = true
        insetShadow.path = outside.cgPath
        insetShadow.shadowPath = outside.cgPath
        bevel.frame = bounds
        bevelMask.frame = bounds
        bevelMask.path = path.cgPath
        rim.path = shape(bounds.insetBy(dx: rim.lineWidth / 2, dy: rim.lineWidth / 2)).cgPath
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyStyle()
    }

    private func applyStyle() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let reduced = effects.paintReduced(calm: calm) || traitCollection.accessibilityContrast == .high
        let fillColor = style == .raised || reduced ? R.color.fwSurfaceRaised() : R.color.fwSurfaceSunken()
        fill.fillColor = fillColor?.resolvedColor(with: traitCollection).cgColor
        dark.shadowOpacity = style == .raised && !reduced ? 0.65 : 0
        light.shadowOpacity = style == .raised && !reduced ? 0.035 : 0
        insetShadow.isHidden = style != .inset || reduced
        insetShadow.shadowOpacity = reduced ? 0 : 0.55
        bevel.isHidden = !reduced
        let color = hasError ? R.color.fwDanger() : (controlFocused ? R.color.fwFocus() : R.color.fwStrokeControl())
        rim.strokeColor = color?.resolvedColor(with: traitCollection).cgColor
        rim.lineWidth = controlFocused || hasError ? 2 : 1
        CATransaction.commit()
    }
}
