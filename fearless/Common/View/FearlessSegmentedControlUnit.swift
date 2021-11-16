import UIKit

class FearlessSegmentedControlUnit: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.size.height / 2
    }

    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    func configure() {
        titleLabel?.font = .capsTitle
        setTitleColor(.white, for: .normal)
    }
}
