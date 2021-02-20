import Foundation
import SoraUI

class AmountInputView: BackgroundedContentControl {
    private(set) var titleLabel: UILabel!
    private(set) var priceLabel: UILabel!
    private(set) var balanceLabel: UILabel!
    private(set) var symbolLabel: UILabel!
    private(set) var textField: UITextField!

    var triangularedBackgroundView: TriangularedView? {
        backgroundView as? TriangularedView
    }

    var iconView: UIImageView { lazyIconViewOrCreateIfNeeded() }
    private var lazyIconView: UIImageView?

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var verticalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var iconRadius: CGFloat = 16.0 {
        didSet {
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let topContentHeight = max(titleLabel.intrinsicContentSize.height,
                                   priceLabel.intrinsicContentSize.height)
        let middleContentHeight = max(lazyIconView?.intrinsicContentSize.height ?? 0.0,
                                      max(symbolLabel.intrinsicContentSize.height,
                                          textField.intrinsicContentSize.height))
        let bottomContentHeight = balanceLabel.intrinsicContentSize.height

        let height = contentInsets.top + topContentHeight + verticalSpacing
            + middleContentHeight + verticalSpacing + bottomContentHeight + contentInsets.bottom

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
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

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        layoutMiddleContent()
        layoutTopContent()
        layoutBottomContent()
    }

    private func layoutMiddleContent() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let symbolSize = symbolLabel.intrinsicContentSize
        if let iconView = lazyIconView {
            iconView.frame = CGRect(x: bounds.minX + contentInsets.left,
                                    y: bounds.midY - iconRadius,
                                    width: 2.0 * iconRadius,
                                    height: 2.0 * iconRadius)

            symbolLabel.frame = CGRect(x: iconView.frame.maxX + horizontalSpacing,
                                       y: bounds.midY - symbolSize.height / 2.0,
                                       width: min(availableWidth, symbolSize.width),
                                       height: symbolSize.height)
        } else {
            symbolLabel.frame = CGRect(x: contentInsets.left,
                                       y: bounds.midY - symbolSize.height / 2.0,
                                       width: min(availableWidth, symbolSize.width),
                                       height: symbolSize.height)
        }

        let estimatedFieldWidth = bounds.maxX - contentInsets.right
            - symbolLabel.frame.maxX - horizontalSpacing
        let fieldWidth = max(estimatedFieldWidth, 0.0)

        let fieldHeight = textField.intrinsicContentSize.height
        textField.frame = CGRect(x: bounds.maxX - contentInsets.right - fieldWidth,
                                 y: bounds.midY - fieldHeight / 2.0,
                                 width: fieldWidth,
                                 height: fieldHeight)
    }

    private func layoutTopContent() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let titleSize = titleLabel.intrinsicContentSize
        let priceSize = priceLabel.intrinsicContentSize

        let middleY = min(min(symbolLabel.frame.minY, textField.frame.minY),
                          lazyIconView?.frame.minY ?? CGFloat.greatestFiniteMagnitude)
        let centerY = middleY - verticalSpacing - max(titleSize.height, priceSize.height) / 2.0

        titleLabel.frame = CGRect(x: bounds.minX + contentInsets.left,
                                  y: centerY - titleSize.height / 2.0,
                                  width: min(availableWidth, titleSize.width),
                                  height: titleSize.height)

        let estimatedPriceWidth = bounds.maxX - contentInsets.right
            - titleLabel.frame.maxX - horizontalSpacing
        let priceWidth = max(min(estimatedPriceWidth, priceSize.width), 0.0)

        priceLabel.frame = CGRect(x: bounds.maxX - contentInsets.right - priceWidth,
                                  y: centerY - priceSize.height / 2.0,
                                  width: priceWidth,
                                  height: priceSize.height)
    }

    private func layoutBottomContent() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let balanceY = max(max(symbolLabel.frame.maxY, textField.frame.maxY),
                           lazyIconView?.frame.maxY ?? 0.0) + verticalSpacing

        balanceLabel.frame = CGRect(x: bounds.minX + contentInsets.left,
                                    y: balanceY,
                                    width: availableWidth,
                                    height: balanceLabel.intrinsicContentSize.height)
    }

    // MARK: Configure

    private func configure() {
        self.backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let triangularedView = TriangularedView()
            triangularedView.isUserInteractionEnabled = false
            triangularedView.shadowOpacity = 0.0

            self.backgroundView = triangularedView
        }
    }

    private func configureContentViewIfNeeded() {
        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            self.contentView = contentView
        }

        if titleLabel == nil {
            titleLabel = UILabel()
            contentView?.addSubview(titleLabel)
        }

        if priceLabel == nil {
            let label = UILabel()
            contentView?.addSubview(label)
            priceLabel = label
        }

        if symbolLabel == nil {
            let label = UILabel()
            contentView?.addSubview(label)
            symbolLabel = label
        }

        if balanceLabel == nil {
            let label = UILabel()
            contentView?.addSubview(label)
            balanceLabel = label
        }

        if textField == nil {
            let field = UITextField()
            field.textAlignment = .right
            contentView?.addSubview(field)
            textField = field
        }
    }

    private func lazyIconViewOrCreateIfNeeded() -> UIImageView {
        if let iconView = lazyIconView {
            return iconView
        }

        let imageView = UIImageView()
        contentView?.addSubview(imageView)

        lazyIconView = imageView

        if superview != nil {
            setNeedsLayout()
        }

        return imageView
    }
}
