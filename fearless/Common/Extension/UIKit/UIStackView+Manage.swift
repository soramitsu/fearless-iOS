import UIKit

extension UIStackView {
    func insertArranged(view: UIView, after otherView: UIView) {
        guard let index = arrangedSubviews.firstIndex(of: otherView) else {
            return
        }

        insertArrangedSubview(view, at: index + 1)
    }

    func insertArranged(view: UIView, before otherView: UIView) {
        guard let index = arrangedSubviews.firstIndex(of: otherView) else {
            return
        }

        insertArrangedSubview(view, at: index)
    }
}
