import UIKit

protocol DeactivatableView {
    var deactivatableViews: [UIView] { get }
    var deactivatedAlpha: CGFloat { get }

    func setDeactivated(_ deactivated: Bool)
}

extension DeactivatableView {
    func setDeactivated(_ deactivated: Bool) {
        let alpha = deactivated ? deactivatedAlpha : 1
        deactivatableViews.forEach { $0.alpha = alpha }
    }

    var deactivatedAlpha: CGFloat {
        0.25
    }
}
