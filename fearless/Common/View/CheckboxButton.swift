import Foundation
import UIKit

class CheckboxButton: UIButton {
    var isChecked: Bool = false {
        didSet {
            if isChecked {
                self.setImage(R.image.iconCheckMark(), for: UIControl.State.normal)
            } else {
                self.setImage(R.image.iconListSelectionOff(), for: UIControl.State.normal)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        let insetAmount = UIConstants.bigOffset / 2
        imageEdgeInsets = UIEdgeInsets(top: 0, left: -insetAmount, bottom: 0, right: insetAmount)
        titleEdgeInsets = UIEdgeInsets(top: 0, left: insetAmount, bottom: 0, right: -insetAmount)
        contentEdgeInsets = UIEdgeInsets(top: 0, left: insetAmount, bottom: 0, right: insetAmount)
    }

    @objc func buttonClicked(sender: UIButton) {
        if sender == self {
            isChecked = !isChecked
        }
    }
}
