import Foundation
import SoraUI

@IBDesignable
final class ProfileButton: BackgroundedContentControl {
    private(set) var titleLabel: UILabel!
    private(set) var subtitleLabel: UILabel!

    public var roundedBackgroundView: RoundedView? {
        return self.backgroundView as? RoundedView
    }

    lazy var highlitedOnAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOn

    lazy var highlitedOffAnimation: ViewAnimatorProtocol = TransformAnimator.highlightedOff

    override var isHighlighted: Bool {
        set {
            let oldValue = super.isHighlighted
            super.isHighlighted = newValue

            if !oldValue, newValue {
                layer.removeAllAnimations()
                highlitedOnAnimation.animate(view: self, completionBlock: nil)
            }

            if oldValue, !newValue {
                layer.removeAllAnimations()
                highlitedOffAnimation.animate(view: self, completionBlock: nil)
            }
        }

        get {
            return super.isHighlighted
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    public func configure() {
        self.backgroundColor = UIColor.clear

        if self.backgroundView == nil {
            self.backgroundView = RoundedView()
            self.backgroundView?.isUserInteractionEnabled = false
        }

        if self.contentView == nil {
            let contentView = UIView()

            titleLabel = UILabel()
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(titleLabel)

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true

            subtitleLabel = UILabel()
            subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subtitleLabel)

            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true

            self.contentView = contentView
            self.contentView?.isUserInteractionEnabled = false
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let currentContentView = contentView else { return }

        let contentSize = CGSize(width: bounds.size.width - contentInsets.left - contentInsets.right,
                                 height: bounds.size.height - contentInsets.top - contentInsets.bottom)
        let contentX = contentInsets.left
        let contentY = contentInsets.top

        currentContentView.frame = CGRect(origin: CGPoint(x: contentX, y: contentY), size: contentSize)
    }
}
