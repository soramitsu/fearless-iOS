import UIKit
import SoraUI

protocol AmountInputAccessoryViewDelegate: class {
    func didSelect(on view: AmountInputAccessoryView, percentage: CGFloat)
    func didSelectDone(on view: AmountInputAccessoryView)
}

class AmountInputAccessoryView: UIToolbar, AdaptiveDesignable {
    weak var actionDelegate: AmountInputAccessoryViewDelegate?

    @objc func actionSelect100() {
        actionDelegate?.didSelect(on: self, percentage: 1.0)
    }

    @objc func actionSelect75() {
        actionDelegate?.didSelect(on: self, percentage: 0.75)
    }

    @objc func actionSelect50() {
        actionDelegate?.didSelect(on: self, percentage: 0.50)
    }

    @objc func actionSelect25() {
        actionDelegate?.didSelect(on: self, percentage: 0.25)
    }

    @objc func actionSelectDone() {
        actionDelegate?.didSelectDone(on: self)
    }
}
