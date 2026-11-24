import SnapKit
import UIKit

/// The stacked lockup (the Yatagarasu crest over the FEARLESS wordmark) for full-page brand screens: PIN, welcome,
/// onboarding start and About. Brand spec 2026-11-10: about 56 % of the page width, at most 280 pt, proportions
/// intact. The crest lights the page as the wallet's round badge does; the welcome turns the light off because the
/// crow's footage is its light.
final class FWLockupView: UIView {
    /// The `fwLockupStacked` artwork's width over its height (master viewBox 640 × 505.30).
    static let aspectRatio: CGFloat = 640 / 505.3032355154251
    /// The share of the page width the lockup takes.
    static let widthFraction: CGFloat = 0.56
    /// The lockup never grows past this, so it stays a mark on a tablet.
    static let maximumWidth: CGFloat = 280
    /// The crest's centre and width as fractions of the artwork (the master draws the 512-unit crest at
    /// translate(120 0) scale(0.78)).
    static let crestCenter = CGPoint(x: (120 + 256 * 0.78) / 640, y: (256 * 0.78) / 505.3032355154251)
    static let crestWidthFraction: CGFloat = 512 * 0.78 / 640
    /// How far the glow reaches above the crest. Pages keep at least this much room above the lockup, because their
    /// scroll views would otherwise cut the light in a straight line.
    static let glowOverhang: CGFloat = 16

    let imageView = UIImageView()
    private let glow = CAGradientLayer()
    private let effects: FWEffects
    private let glows: Bool
    private var observation: NSObjectProtocol?
    private var heightLimit: Constraint?
    private var appliedHeightLimit: CGFloat?
    private var windowWidth: Constraint?
    private var appliedWindowWidth: CGFloat?

    /// Whether the warm light is showing behind the crest.
    var isGlowing: Bool { !glow.isHidden }
    /// The glow's frame in this view's coordinates.
    var glowFrame: CGRect { glow.frame }
    /// The crest's centre in this view's coordinates: the page light's source.
    var crestCenterPoint: CGPoint {
        CGPoint(x: bounds.width * Self.crestCenter.x, y: bounds.height * Self.crestCenter.y)
    }

    /// The lockup's tallest share of the window's height, for pages whose controls must keep their room (PIN).
    var maximumHeightFraction: CGFloat? {
        didSet { updateWindowConstraints() }
    }

    init(effects: FWEffects = .shared, glows: Bool = true) {
        self.effects = effects
        self.glows = glows
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityLabel = "Fearless"
        accessibilityTraits = .image
        imageView.image = R.image.fwLockupStacked()
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = false
        // The artwork's own 640 × 505 pt size must never size the lockup; the page constraints do.
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            imageView.setContentHuggingPriority(.fittingSizeLevel, for: axis)
            imageView.setContentCompressionResistancePriority(.fittingSizeLevel, for: axis)
        }
        glow.type = .radial
        glow.colors = [
            FWSunlit.Palette.sun.withAlphaComponent(0.5),
            FWSunlit.Palette.brand.withAlphaComponent(0.22),
            FWSunlit.Palette.brand.withAlphaComponent(0)
        ].map(\.cgColor)
        glow.locations = [0, 0.55, 1]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.opacity = FWSunBadgeView.restingGlow
        layer.addSublayer(glow)
        addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        snp.makeConstraints { make in
            make.height.equalTo(snp.width).dividedBy(Self.aspectRatio)
            heightLimit = make.height.lessThanOrEqualTo(0).constraint
            windowWidth = make.width.equalTo(0).priority(.high).constraint
        }
        heightLimit?.deactivate()
        windowWidth?.deactivate()
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

    /// Centres the lockup in its superview at 56 % of the window's width, up to `maximumWidth` and never wider than
    /// the superview. It narrows further when the page or `maximumHeightFraction` leaves less height. Until the lockup
    /// is in a window, 56 % of the superview stands in.
    func makePageConstraints(_ make: ConstraintMaker) {
        make.centerX.equalToSuperview()
        make.leading.greaterThanOrEqualToSuperview()
        make.width.lessThanOrEqualTo(Self.maximumWidth)
        make.width.equalToSuperview().multipliedBy(Self.widthFraction).priority(.medium)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateWindowConstraints()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateWindowConstraints()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // A warm light behind the crest, as on the app icon. At 1.15 crest widths it reaches at most 13 pt above the
        // artwork at the maximum width, inside `glowOverhang`.
        let side = bounds.width * Self.crestWidthFraction * 1.15
        let center = crestCenterPoint
        glow.frame = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyEffects()
    }

    /// Follows the current window: 56 % of its width and `maximumHeightFraction` of its height. Constraints change only
    /// when a value does, so layout passes settle.
    private func updateWindowConstraints() {
        let width = window.map { ($0.bounds.width * Self.widthFraction).rounded(.down) }
        if width != appliedWindowWidth {
            appliedWindowWidth = width
            if let width {
                windowWidth?.update(offset: width)
                windowWidth?.activate()
            } else {
                windowWidth?.deactivate()
            }
        }
        let limit = maximumHeightFraction.flatMap { fraction in
            window.map { ($0.bounds.height * fraction).rounded(.down) }
        }
        if limit != appliedHeightLimit {
            appliedHeightLimit = limit
            if let limit {
                heightLimit?.update(offset: limit)
                heightLimit?.activate()
            } else {
                heightLimit?.deactivate()
            }
        }
    }

    private func applyEffects() {
        glow.isHidden = !glows || effects.paintReduced(calm: false) || traitCollection.accessibilityContrast == .high
    }
}
