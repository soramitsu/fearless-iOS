import UIKit

/// Explicit paths keep the one permitted glow inexpensive. The caller owns the sibling halo layer
/// and reapplies this recipe after geometry/effects changes; never use it on a Calm surface.
enum FWGlow {
    enum Style { case primary, pending, focus, success }

    static func apply(
        to view: UIView, halo: CALayer, path: UIBezierPath, style: Style = .primary,
        enabled: Bool, calm: Bool = false, effects: FWEffects = .shared
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard enabled, !effects.paintReduced(calm: calm), view.traitCollection.accessibilityContrast != .high else {
            view.layer.shadowOpacity = 0
            halo.shadowOpacity = 0
            return
        }
        view.layer.masksToBounds = false
        view.layer.shadowPath = path.cgPath
        halo.frame = view.frame
        halo.shadowPath = path.cgPath
        let color: UIColor?
        switch style {
        case .primary, .pending: color = R.color.fwBrand()
        case .focus: color = R.color.fwFocus()
        case .success: color = R.color.fwSuccess()
        }
        view.layer.shadowColor = color?.resolvedColor(with: view.traitCollection).cgColor
        halo.shadowColor = view.layer.shadowColor
        halo.shadowOffset = .zero
        halo.shadowRadius = 20
        halo.shadowOpacity = style == .primary ? 0.35 : 0
        view.layer.shadowOffset = style == .primary ? CGSize(width: 0, height: 6) : .zero
        view.layer.shadowRadius = style == .primary ? 12 : 8
        switch style {
        case .primary: view.layer.shadowOpacity = 0.55
        case .pending: view.layer.shadowOpacity = 0.4
        case .focus: view.layer.shadowOpacity = 0.28
        case .success: view.layer.shadowOpacity = 0.15
        }
    }
}
