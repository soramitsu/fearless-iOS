import Foundation
import UIKit

class CheckboxButton: UIButton {
    var isChecked: Bool = false {
        didSet {
            if isChecked == true {
                self.setImage(R.image.iconCheckMark(), for: UIControl.State.normal)
            } else {
                self.setImage(nil, for: UIControl.State.normal)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isChecked = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rounded()
        layer.borderWidth = 1
        layer.borderColor = R.color.colorWhite8()?.cgColor
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func buttonClicked(sender: UIButton) {
        if sender == self {
            isChecked = !isChecked
        }
    }
}
