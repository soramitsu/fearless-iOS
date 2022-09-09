import Foundation
import UIKit

class ShadowRoundedBackground: UIView {
    var shadowColor: UIColor = .clear {
        didSet {
            configureShadow()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureShadow()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = frame.size.height / 2
    }

    func configureShadow() {
        layer.shadowColor = shadowColor.cgColor
        layer.shadowRadius = 15.0
        layer.shadowOpacity = 0.5
    }
}
