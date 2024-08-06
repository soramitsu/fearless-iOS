import UIKit

extension UIControl {
    func disable(with alpha: CGFloat = 0.5) {
        isEnabled = false
        self.alpha = alpha
    }

    func enable() {
        isEnabled = true
        alpha = 1.0
    }
}
