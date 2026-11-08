import SnapKit
import UIKit

/// The winged-sun mark at full span, for pages with room for it (PIN, welcome, About): the approved badge's
/// wings, joint and disc without the circle. It lights the page as the badge does. Sync states stay on the
/// wallet's round hero sun, whose arc needs the circle.
final class FWWingsView: UIView {
    /// The `fwWings` artwork's width over its height.
    static let aspectRatio: CGFloat = 480 / 132
    /// Keeps the mark from taking over a tablet's height.
    static let maximumWidth: CGFloat = 480

    let imageView = UIImageView()
    private let glow = CAGradientLayer()
    private let effects: FWEffects
    private var observation: NSObjectProtocol?

    /// Whether the sun's glow is showing behind the mark.
    var isGlowing: Bool { !glow.isHidden }

    init(effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        imageView.image = R.image.fwWings()
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = false
        glow.type = .radial
        glow.colors = [
            FWSunlit.Palette.sun.withAlphaComponent(0.55),
            FWSunlit.Palette.brand.withAlphaComponent(0.18),
            FWSunlit.Palette.brand.withAlphaComponent(0)
        ].map(\.cgColor)
        glow.locations = [0, 0.45, 1]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.opacity = FWSunBadgeView.restingGlow
        layer.addSublayer(glow)
        addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        snp.makeConstraints { $0.height.equalTo(snp.width).dividedBy(Self.aspectRatio) }
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

    /// Centres the mark in its superview at the superview's width, up to `maximumWidth`.
    func makeWideConstraints(_ make: ConstraintMaker) {
        make.centerX.equalToSuperview()
        make.leading.greaterThanOrEqualToSuperview()
        make.width.lessThanOrEqualTo(Self.maximumWidth)
        make.width.equalToSuperview().priority(.high)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // The light runs along the wings and fades before it reaches the text above and below the mark.
        glow.frame = bounds.insetBy(dx: -bounds.width * 0.1, dy: -bounds.height * 0.55)
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyEffects()
    }

    private func applyEffects() {
        glow.isHidden = effects.paintReduced(calm: false) || traitCollection.accessibilityContrast == .high
    }
}
