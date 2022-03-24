import UIKit

protocol DeactivatableView {
    var deactivatableViews: [UIView] { get }

    func setDeactivated(_ deactivated: Bool)
}

extension DeactivatableView {
    func setDeactivated(_ deactivated: Bool) {
        let alpha = deactivated ? 0.25 : 1
        deactivatableViews.forEach { $0.alpha = alpha }
    }
}
