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

    /// Kit v3: the glass capsule's lit rim.
    let rim = FWLitRimLayer()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = false
        isUserInteractionEnabled = false
        addSubview(surface)
        rim.cornerRadiusValue = FWSunlit.Radius.tabBar
        surface.layer.addSublayer(rim)
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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rim.frame = surface.bounds
        CATransaction.commit()
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
        // The active tab is pink; its label and icon use the text pink, which keeps 4.5:1 on the bar.
        appearance.stackedLayoutAppearance.selected.iconColor = FWSunlit.Palette.brandText
        tabBar.tintColor = FWSunlit.Palette.brandText
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
        var center = Self.wellCenter(
            in: tabBar.bounds, bottomInset: tabBar.safeAreaInsets.bottom, selectedIndex: selectedIndex
        )
        // The glow and its gold dot mark every selected tab but the Polkaswap orb; the inset well itself shows only
        // where the system draws no selection of its own.
        var visible = Self.showsActiveGlow(selectedIndex: selectedIndex)
        if Self.systemDrawsSelection, visible {
            // From iOS 26 the system lays the items out itself, not in equal slots: follow the selected item's frame.
            if let frame = Self.systemItemFrame(in: tabBar, title: tabBar.selectedItem?.title) {
                center = CGPoint(x: frame.midX, y: frame.midY)
            } else {
                visible = false
            }
        }
        if let target = target, target.center == center, target.visible == visible { return }
        target = (center, visible)
        view.systemDrawsSelection = Self.systemDrawsSelection
        view.move(to: center, visible: visible, animated: animated && placed)
        placed = true
    }

    /// From iOS 26 the system tab bar draws its own sliding selection.
    static var systemDrawsSelection: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// The drawn frame of the tab item titled `title`, in the tab bar's coordinates: the widest visible view with that
    /// accessibility label (the item, rather than its label inside it). Nil when the system draws none.
    static func systemItemFrame(in tabBar: UITabBar, title: String?) -> CGRect? {
        guard let title, !title.isEmpty else { return nil }
        var best: CGRect?
        func visit(_ view: UIView) {
            for subview in view.subviews where !subview.isHidden && subview.alpha > 0.01 {
                if subview.accessibilityLabel == title, subview.bounds.width >= 24,
                   subview.bounds.width < tabBar.bounds.width / 2 {
                    let frame = subview.convert(subview.bounds, to: tabBar)
                    if frame.width > (best?.width ?? 0) { best = frame }
                }
                visit(subview)
            }
        }
        visit(tabBar)
        return best
    }

    /// The selected tab's glow and gold dot: never under the raised Polkaswap orb, which carries its own light.
    static func showsActiveGlow(selectedIndex: Int) -> Bool {
        selectedIndex != MainTabBarDestination.polkaswap.rawValue
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
