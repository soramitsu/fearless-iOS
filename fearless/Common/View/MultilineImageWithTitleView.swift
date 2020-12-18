import UIKit

final class MultilineImageWithTitleView: UIView {
    private(set) var imageView: UIImageView!
    private(set) var titleLabel: UILabel!

    private var calculatedWidth: CGFloat = 0.0
    private var calculatedTitleHeight: CGFloat = 0.0

    var preferredWidth: CGFloat = 220.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0, right: 16.0) {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var verticalSpacing: CGFloat = 4.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let height = contentInsets.top + imageView.intrinsicContentSize.height +
            verticalSpacing + calculatedTitleHeight + contentInsets.bottom
        return CGSize(width: preferredWidth, height: height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    func invalidateLayout() {
        calculatedWidth = 0.0
        calculatedTitleHeight = 0.0

        setNeedsLayout()
    }

    func forceSizeCalculation() {
        let availableWidth = preferredWidth - contentInsets.left - contentInsets.right
        updateTitleSizeForWidth(availableWidth)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let availableWidth = preferredWidth - contentInsets.left - contentInsets.right

        let imageSize = imageView.intrinsicContentSize
        imageView.frame = CGRect(x: bounds.midX - imageSize.width / 2.0,
                                 y: contentInsets.top,
                                 width: imageSize.width,
                                 height: imageSize.height)

        if abs(calculatedWidth - availableWidth) > CGFloat.leastNormalMagnitude {
            updateTitleSizeForWidth(availableWidth)
        }

        titleLabel.frame = CGRect(x: bounds.midX - calculatedWidth / 2.0,
                                  y: imageView.frame.maxY + verticalSpacing,
                                  width: calculatedWidth,
                                  height: calculatedTitleHeight)
    }

    private func configure() {
        if imageView == nil {
            imageView = UIImageView()
            addSubview(imageView)
        }

        if titleLabel == nil {
            titleLabel = UILabel()
            titleLabel.numberOfLines = 0
            addSubview(titleLabel)
        }
    }

    private func updateTitleSizeForWidth(_ width: CGFloat) {
        calculatedWidth = width
        calculatedTitleHeight = titleLabel
            .sizeThatFits(CGSize(width: width,
                                 height: CGFloat.greatestFiniteMagnitude)).height

        invalidateIntrinsicContentSize()
    }
}
