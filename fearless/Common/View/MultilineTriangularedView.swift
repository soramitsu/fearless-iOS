import UIKit

class MultilineTriangularedView: UIView {
    private(set) var backgroundView: TriangularedView!
    private(set) var titleLabel: UILabel!
    private(set) var subtitleLabel: UILabel!

    private var calculatedSubtitleWidth: CGFloat = 0.0
    private var calculatedSubtitleHeight: CGFloat = 0.0

    override var intrinsicContentSize: CGSize {
        let height = contentInsets.top + titleLabel.intrinsicContentSize.height + verticalSpacing +
            calculatedSubtitleHeight + contentInsets.bottom
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
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

    override func layoutSubviews() {
        super.layoutSubviews()

        let availableWidth = bounds.width - contentInsets.left - contentInsets.right

        backgroundView.frame = bounds

        titleLabel.frame = CGRect(x: bounds.minX + contentInsets.left,
                                  y: bounds.minY + contentInsets.top,
                                  width: availableWidth,
                                  height: titleLabel.intrinsicContentSize.height)

        if abs(calculatedSubtitleWidth - availableWidth) > CGFloat.leastNormalMagnitude {
            updateSubtitleSizeForWidth(availableWidth)
        }

        subtitleLabel.frame = CGRect(x: bounds.minX + contentInsets.left,
                                     y: titleLabel.frame.maxY + verticalSpacing,
                                     width: calculatedSubtitleWidth,
                                     height: calculatedSubtitleHeight)
    }

    private func configure() {
        backgroundColor = .clear

        if backgroundView == nil {
            backgroundView = TriangularedView()
            backgroundView.isUserInteractionEnabled = false
            backgroundView.shadowOpacity = 0.0
            addSubview(backgroundView)
        }

        if titleLabel == nil {
            titleLabel = UILabel()
            addSubview(titleLabel)
        }

        if subtitleLabel == nil {
            subtitleLabel = UILabel()
            subtitleLabel.numberOfLines = 0
            addSubview(subtitleLabel)
        }
    }

    private func updateSubtitleSizeForWidth(_ width: CGFloat) {
        calculatedSubtitleWidth = width
        calculatedSubtitleHeight = subtitleLabel
            .sizeThatFits(CGSize(width: width,
                                 height: CGFloat.greatestFiniteMagnitude)).height

        invalidateIntrinsicContentSize()
    }
}
