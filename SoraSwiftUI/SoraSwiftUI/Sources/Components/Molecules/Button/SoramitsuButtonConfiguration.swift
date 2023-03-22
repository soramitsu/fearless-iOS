import UIKit

public final class SoramitsuButtonConfiguration<Type: SoramitsuButton>: SoramitsuBaseButtonConfiguration<Type,
                                                                        SoramitsuButtonConfiguration>, Statable {
    public var leftImage: UIImage? {
        didSet {
            owner?.leftImageView.isHidden = leftImage == nil
            owner?.leftImageView.image = leftImage
            owner?.leftImageView.tintColor = owner?.tintColor
        }
    }

    public var title: String? {
        didSet {
            owner?.titleLabel.sora.isHidden = title == nil || (title?.isEmpty ?? true)
            owner?.titleLabel.sora.text = self.size == .extraSmall ? title : title?.uppercased()
        }
    }

    public var attributedText: SoramitsuAttributedText? {
        didSet {
            let isHidden = attributedText == nil || (attributedText?.attributedString.string.isEmpty ?? true)
            owner?.titleLabel.sora.isHidden = isHidden
            owner?.titleLabel.sora.attributedText = attributedText
        }
    }
    
    public var imageSize: CGFloat? {
        didSet {
            owner?.rightImageSizeConstaint?.constant = imageSize ?? 24
            owner?.leftImageSizeConstaint?.constant = imageSize ?? 24
        }
    }

    public var rightImage: UIImage? {
        didSet {
            owner?.rightImageView.isHidden = rightImage == nil
            owner?.rightImageView.image = rightImage
            owner?.rightImageView.tintColor = owner?.tintColor
        }
    }
    
    public var horizontalOffset: CGFloat? {
        didSet {
            owner?.horizontalConstaint?.constant = horizontalOffset ?? 16
            owner?.horizontalConstaint?.isActive = true
        }
    }

    public var isHighlited: Bool = false {
        didSet {
            guard isHighlited else { return }
            owner?.pressedAnimation()
        }
    }

	init(style: SoramitsuStyle) {
		super.init(style: style, stater: SoramitsuStateDecorator(state: .default))
		stater.g = self
	}

    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)

        if options.contains(.palette) {
            owner?.updateView()
        }
    }
}
