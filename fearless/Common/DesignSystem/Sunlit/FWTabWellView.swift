import UIKit

/// The light "well" under the selected tab (spec section 4: it slides under the new tab with a 260 ms
/// spring). An inset rounded well in a soft pink glow, with a small gold dot (kit v3 design pass); touches pass
/// through to the tab. Where the system draws its own selection the well hides and the glow and dot remain.
final class FWTabWellView: UIView {
    static let size = CGSize(width: 56, height: 46)
    let well: FWNeuView
    let dot = UIView()
    let glow = CAGradientLayer()
    private let effects: FWEffects

    /// The system draws the selection (iOS 26 and later): the dot sits inside the top of its pill.
    var systemDrawsSelection = false {
        didSet {
            well.isHidden = systemDrawsSelection
            setNeedsLayout()
        }
    }

    init(effects: FWEffects = .shared) {
        self.effects = effects
        well = FWNeuView(effects: effects)
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        well.isUserInteractionEnabled = false
        well.style = .inset
        well.shape = { UIBezierPath(roundedRect: $0, cornerRadius: FWSunlit.Radius.tabWell) }
        glow.type = .radial
        glow.colors = [FWSunlit.Palette.brand.withAlphaComponent(0.34), FWSunlit.Palette.brand.withAlphaComponent(0)]
            .map(\.cgColor)
        glow.locations = [0, 1]
        layer.addSublayer(glow)
        addSubview(well)
        dot.backgroundColor = FWSunlit.Palette.sun
        dot.layer.shadowColor = FWSunlit.Palette.sun.cgColor
        dot.layer.shadowOpacity = 0.9
        dot.layer.shadowRadius = 4
        dot.layer.shadowOffset = .zero
        dot.isUserInteractionEnabled = false
        addSubview(dot)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        well.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glow.frame = bounds.insetBy(dx: -bounds.width * 0.45, dy: -bounds.height * 0.55)
        CATransaction.commit()
        let dotSide: CGFloat = 5
        let dotY = systemDrawsSelection ? bounds.minY + 3 : bounds.maxY + 2
        dot.frame = CGRect(x: bounds.midX - dotSide / 2, y: dotY, width: dotSide, height: dotSide)
        dot.layer.cornerRadius = dotSide / 2
        dot.layer.shadowPath = UIBezierPath(ovalIn: dot.bounds).cgPath
    }

    /// Moves the well under `center` (in the superview). The first placement and Reduce Motion jump or fade.
    func move(to center: CGPoint, visible: Bool, animated: Bool) {
        let style = FWMotionPolicy.current(effects: effects).style(for: .tabChange)
        let alpha: CGFloat = visible ? 1 : 0
        guard animated, style.animates, self.alpha > 0 || visible else {
            self.center = center
            self.alpha = alpha
            return
        }
        switch style {
        case let .full(duration):
            UIView.animate(
                withDuration: duration, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.4,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                self.center = center
                self.alpha = alpha
            }
        case let .crossfade(duration):
            UIView.animate(withDuration: duration / 2, delay: 0, options: [.beginFromCurrentState]) {
                self.alpha = 0
            } completion: { _ in
                self.center = center
                UIView.animate(withDuration: duration / 2) { self.alpha = alpha }
            }
        case .none:
            self.center = center
            self.alpha = alpha
        }
    }
}

extension FWNeuView {
    /// The selected segment's Raised-1 thumb inside an inset segmented track.
    static func segmentThumb() -> FWNeuView {
        let view = FWNeuView()
        view.style = .raised1
        view.isUserInteractionEnabled = false
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: min(FWSunlit.Radius.button, $0.height / 2)) }
        return view
    }
}
