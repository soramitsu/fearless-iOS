import UIKit

/// The page under every sun-lit screen: the `bg` base, the sun's warm bounce around the sun and the violet
/// ambient sky from the bottom-right corner (spec section 2). Static paint; High contrast and Reduced
/// effects keep only the base.
final class FWSunlitBackgroundView: UIView {
    /// Sun centre in this view's coordinates. Nil places it at the top centre, 21 % down.
    var sunCenter: CGPoint? {
        didSet { setNeedsLayout() }
    }

    /// Dims the bounce, for a sun that is dimmed because the wallet could not sync.
    var bounceIntensity: CGFloat = 1 {
        didSet { applyStyle() }
    }

    /// The bounce reaches 1.44 screen widths (2.4 halvings), where it is cut off at about 3 %.
    static let bounceReach: CGFloat = 2.4 * FWSunlit.Light.bounceHalfDistance
    static let bounceStops: [CGFloat] = [0, 0.25, 0.5, 0.75, 1]

    private let effects: FWEffects
    private var observation: NSObjectProtocol?
    private let bounce = CAGradientLayer()
    private let sky = CAGradientLayer()

    init(frame: CGRect = .zero, effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: frame)
        backgroundColor = FWSunlit.Palette.background
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        for layer in [sky, bounce] {
            layer.type = .radial
            self.layer.addSublayer(layer)
        }
        // Stops sample the spec's falloff (halving every 0.6 widths) out to `Self.bounceReach` widths.
        let brand = FWSunlit.Palette.brand
        bounce.colors = Self.bounceStops.map { stop in
            let alpha = stop < 1 ? FWSunlit.Light.bounce(distance: stop * Self.bounceReach, screenWidth: 1) : 0
            return brand.withAlphaComponent(alpha)
        }.map(\.cgColor)
        bounce.locations = Self.bounceStops.map { NSNumber(value: Double($0)) }
        let violet = FWSunlit.Palette.violet
        sky.colors = [
            violet.withAlphaComponent(FWSunlit.Light.skyAlpha), violet.withAlphaComponent(0)
        ].map(\.cgColor)
        sky.locations = [0, 1]
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
        guard bounds.width > 0, bounds.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bounce.frame = bounds
        sky.frame = bounds
        let width = bounds.width
        let height = bounds.height
        let sun = sunCenter ?? CGPoint(
            x: width * FWSunlit.Light.defaultSunPosition.x, y: height * FWSunlit.Light.defaultSunPosition.y
        )
        let reach = Self.bounceReach * width
        bounce.startPoint = CGPoint(x: sun.x / width, y: sun.y / height)
        bounce.endPoint = CGPoint(x: (sun.x + reach) / width, y: (sun.y + reach) / height)
        let skyReach = FWSunlit.Light.skyReach * hypot(width, height)
        sky.startPoint = CGPoint(x: 1, y: 1)
        sky.endPoint = CGPoint(x: 1 + skyReach / width, y: 1 + skyReach / height)
        CATransaction.commit()
    }

    /// Puts the page light behind everything in `view` (screens without a sun of their own).
    @discardableResult
    static func install(in view: UIView) -> FWSunlitBackgroundView {
        let background = FWSunlitBackgroundView()
        background.frame = view.bounds
        background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(background, at: 0)
        return background
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyStyle()
    }

    private func applyStyle() {
        let plain = effects.paintReduced() || effects.highContrast || traitCollection.accessibilityContrast == .high
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bounce.isHidden = plain
        sky.isHidden = plain
        bounce.opacity = Float(max(0, min(1, bounceIntensity)))
        CATransaction.commit()
    }
}
