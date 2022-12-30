import SnapKit
import UIKit

extension UIView {
    func addSubview(_ view: UIView, constraints: (_ make: ConstraintMaker) -> Void) {
        addSubview(view)
        view.snp.makeConstraints(constraints)
    }
}

extension UIStackView {
    func addArrangedSubview(_ view: UIView, constraints: (_ make: ConstraintMaker) -> Void) {
        addArrangedSubview(view)
        view.snp.makeConstraints(constraints)
    }
}
