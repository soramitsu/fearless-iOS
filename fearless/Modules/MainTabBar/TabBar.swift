import Foundation
import UIKit

/// The raised Polkaswap orb: an emissive brand-gradient circle with its own glow (sun-lit redesign).
final class TabBarMiddleButton: UIButton {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let image = R.image.polkaswapPinkButton()?.withRenderingMode(.alwaysTemplate)
        setImage(image, for: .normal)
        tintColor = .white
        backgroundColor = .clear
        accessibilityLabel = "Polkaswap"
        accessibilityTraits = .button
        gradient.colors = [FWSunlit.Palette.gradientStart, FWSunlit.Palette.gradientEnd].map(\.cgColor)
        gradient.startPoint = .zero
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
        layer.borderColor = UIColor(white: 1, alpha: FWSunlit.Rim.emissiveHighlightAlpha).cgColor
        layer.borderWidth = 1
        layer.shadowColor = FWSunlit.Palette.brand.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 11
        layer.shadowOpacity = 0.45
    }

    override var isSelected: Bool {
        didSet {
            layer.shadowOpacity = isSelected ? 0.8 : 0.45
            transform = isSelected ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
            accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            gradient.opacity = isHighlighted ? 0.86 : 1
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rounded()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        gradient.cornerRadius = bounds.height / 2
        layer.shadowPath = UIBezierPath(ovalIn: bounds).cgPath
        CATransaction.commit()
        if let imageView = imageView {
            bringSubviewToFront(imageView)
        }
    }
}

/// Extends the raised artwork's touch region above the tab bar. UIKit can hide
/// the bar after an animated push without laying out its controller again, so
/// every touch re-checks that the artwork is still on screen.
final class TabBarMiddleButtonTouchTarget: UIControl {
    var acceptsTouches: () -> Bool = { false }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        acceptsTouches() && super.point(inside: point, with: event)
    }
}

/// The tab bar: a floating Raised-2 capsule lit from the top-left, with the selected tab's light well
/// sliding beneath its items (sun-lit redesign). It never takes touches.
final class TabBarBackgroundView: UIView {
    let surface: FWNeuView = {
        let view = FWNeuView()
        view.style = .raised
        view.isUserInteractionEnabled = false
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: FWSunlit.Radius.tabBar) }
        return view
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = false
        isUserInteractionEnabled = false
        addSubview(surface)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The capsule around the tab items: inset from the sides, clear of the home indicator.
    static func capsuleFrame(in bounds: CGRect, bottomInset: CGFloat) -> CGRect {
        let itemHeight = max(44, bounds.height - bottomInset)
        let top: CGFloat = -4
        let bottom = min(itemHeight + 6, bounds.height - 2)
        return CGRect(x: 12, y: top, width: max(0, bounds.width - 24), height: max(44, bottom - top))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        surface.frame = Self.capsuleFrame(in: bounds, bottomInset: safeAreaInsets.bottom)
    }
}

/// A single accessible action for each surrounding tab avoids announcing the
/// system center item a second time beside the raised Polkaswap button.
final class TabBarAccessibilityElement: UIAccessibilityElement {
    private let activate: () -> Void

    init(container: Any, activate: @escaping () -> Void) {
        self.activate = activate
        super.init(accessibilityContainer: container)
    }

    override func accessibilityActivate() -> Bool {
        activate()
        return true
    }
}

/// The selected tab's light well and the tab colours (sun-lit redesign). The well slides beneath the items
/// with a spring; the raised Polkaswap orb carries its own light, so the well hides for it.
final class TabBarSunlitWell {
    let view = FWTabWellView()
    private var placed = false
    private var target: (center: CGPoint, visible: Bool)?

    static func applyColors(to tabBar: UITabBar, appearance: UITabBarAppearance) {
        appearance.stackedLayoutAppearance.normal.iconColor = FWSunlit.Palette.textTertiary
        appearance.stackedLayoutAppearance.selected.iconColor = FWSunlit.Palette.brand
        tabBar.tintColor = FWSunlit.Palette.brand
        tabBar.unselectedItemTintColor = FWSunlit.Palette.textTertiary
    }

    /// Keeps the well directly above the tab bar's background.
    func keep(in tabBar: UITabBar, above background: UIView) {
        if tabBar.subviews[safe: 1] !== view {
            tabBar.insertSubview(view, aboveSubview: background)
        }
    }

    func update(in tabBar: UITabBar, selectedIndex: Int, animated: Bool) {
        guard tabBar.bounds.width > 0 else { return }
        view.bounds = CGRect(origin: .zero, size: FWTabWellView.size)
        let center = Self.wellCenter(
            in: tabBar.bounds, bottomInset: tabBar.safeAreaInsets.bottom, selectedIndex: selectedIndex
        )
        let visible = Self.showsWell(selectedIndex: selectedIndex, systemDrawsSelection: Self.systemDrawsSelection)
        if let target = target, target.center == center, target.visible == visible { return }
        target = (center, visible)
        view.move(to: center, visible: visible, animated: animated && placed)
        placed = true
    }

    /// From iOS 26 the system tab bar draws its own sliding selection.
    static var systemDrawsSelection: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// The well marks the selected tab only where the system draws no selection of its own, and never under
    /// the raised Polkaswap orb.
    static func showsWell(selectedIndex: Int, systemDrawsSelection: Bool) -> Bool {
        !systemDrawsSelection && selectedIndex != MainTabBarDestination.polkaswap.rawValue
    }

    /// The middle of the selected tab's equal slot, on the raised capsule's midline.
    static func wellCenter(in bounds: CGRect, bottomInset: CGFloat, selectedIndex: Int) -> CGPoint {
        let slot = bounds.width / CGFloat(MainTabBarDestination.allCases.count)
        let capsule = TabBarBackgroundView.capsuleFrame(in: bounds, bottomInset: bottomInset)
        return CGPoint(x: slot * (CGFloat(selectedIndex) + 0.5), y: capsule.midY - 2)
    }
}
