import UIKit

/// A section container with no live blur. Do not instantiate a masked gradient per list cell.
final class FWGlassPanelView: UIView {
    var shape: (CGRect) -> UIBezierPath = { UIBezierPath(roundedRect: $0, cornerRadius: FWTokens.Radius.m) } {
        didSet { setNeedsLayout() }
    }

    var accent = false {
        didSet { applyStyle() }
    }

    var calm = false {
        didSet { applyStyle() }
    }

    private let effects: FWEffects
    private var observation: NSObjectProtocol?
    private let fill = CAShapeLayer()
    private let sheen = CAShapeLayer()
    private let hairline = CAGradientLayer()
    private let hairlineMask = CAShapeLayer()

    init(frame: CGRect = .zero, effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = false
        [fill, sheen, hairline].forEach(layer.addSublayer)
        hairline.startPoint = .zero
        hairline.endPoint = CGPoint(x: 1, y: 1)
        hairline.mask = hairlineMask
        hairlineMask.fillColor = nil
        hairlineMask.strokeColor = UIColor.black.cgColor
        hairlineMask.lineWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 12)
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
        let path = shape(bounds).cgPath
        fill.path = path
        sheen.path = path
        layer.shadowPath = path
        hairline.frame = bounds
        hairlineMask.frame = hairline.bounds
        hairlineMask.path = shape(bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
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
        let fillColor = reduced ? R.color.fwSurfaceRaised() : R.color.fwSurfaceGlass()
        fill.fillColor = fillColor?.resolvedColor(with: traitCollection).cgColor
        sheen.fillColor = UIColor(white: 1, alpha: reduced ? 0 : FWTokens.Alpha.glassSheen).cgColor
        layer.shadowOpacity = reduced ? 0 : 0.6
        if reduced {
            let contrast = effects.highContrast || traitCollection.accessibilityContrast == .high
            let color = contrast ? R.color.fwStrokeControl() : R.color.fwStrokeStrong()
            let stroke = color?.resolvedColor(with: traitCollection).cgColor ?? UIColor.clear.cgColor
            hairline.colors = Array(repeating: stroke, count: 3)
            hairline.locations = [0, 0.5, 1]
        } else {
            let gradient = accent ? FWTokens.Gradients.accent : FWTokens.Gradients.hairline
            hairline.colors = gradient.colors.map(\.cgColor)
            hairline.locations = gradient.locations
        }
        CATransaction.commit()
    }
}
