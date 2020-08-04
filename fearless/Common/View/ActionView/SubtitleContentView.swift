import SoraUI

final class SubtitleContentView: UIView {
    let titleLabel: UILabel = UILabel()
    let subtitleImageView: UIImageView = UIImageView()
    let subtitleLabelView: UILabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    private func configure() {
        if titleLabel.superview == nil {
            addSubview(titleLabel)
        }

        if subtitleImageView.superview == nil {
            addSubview(subtitleImageView)
        }

        if subtitleLabelView.superview == nil {
            addSubview(subtitleLabelView)
        }
    }

    var verticalSpacing: CGFloat = 3.0 {
        didSet {
            invalidateLayout()
        }
    }

    var horizontalSubtitleSpacing: CGFloat = 8.0 {
        didSet {
            invalidateLayout()
        }
    }

    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    // MARK: Overriding

    override var intrinsicContentSize: CGSize {
        let titleSize = titleLabel.intrinsicContentSize
        var subtitleSize = subtitleLabelView.intrinsicContentSize

        if let image = subtitleImageView.image {
            subtitleSize.width += image.size.width + horizontalSubtitleSpacing
            subtitleSize.height = max(image.size.height, subtitleSize.height)
        }

        let width = max(titleSize.width, subtitleSize.width)
        let height = titleSize.height + verticalSpacing + subtitleSize.height

        return CGSize(width: width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let titleSize = titleLabel.intrinsicContentSize

        titleLabel.frame = CGRect(x: bounds.minX,
                                  y: bounds.minY,
                                  width: min(titleSize.width, bounds.width),
                                  height: titleSize.height)

        let subtitleLabelSize = subtitleLabelView.intrinsicContentSize
        var subtitleHeight = subtitleLabelSize.height

        var originX = bounds.minX
        var availableWidth = bounds.size.width

        if let image = subtitleImageView.image {
            subtitleHeight = max(image.size.height, subtitleHeight)

            let imageOrigin = titleLabel.frame.maxY + verticalSpacing +
                subtitleHeight / 2.0 - image.size.height / 2.0
            subtitleImageView.frame = CGRect(x: originX,
                                             y: imageOrigin,
                                             width: image.size.width,
                                             height: image.size.height)

            originX = subtitleImageView.frame.maxX + horizontalSubtitleSpacing
            availableWidth -= originX
        }

        let labelOrigin = titleLabel.frame.maxY + verticalSpacing +
            subtitleHeight / 2.0 - subtitleLabelSize.height / 2.0

        subtitleLabelView.frame = CGRect(x: originX,
                                         y: labelOrigin,
                                         width: availableWidth,
                                         height: subtitleLabelSize.height)
    }
}
