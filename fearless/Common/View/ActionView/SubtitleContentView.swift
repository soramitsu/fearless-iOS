import SoraUI

final class SubtitleContentView: UIView {
    let titleLabel: UILabel = UILabel()
    let subtitleView: ImageWithTitleView = ImageWithTitleView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    private func configure() {
        backgroundColor = .clear

        if titleLabel.superview == nil {
            addSubview(titleLabel)
        }

        if subtitleView.superview == nil {
            addSubview(subtitleView)
        }
    }

    var verticalSpacing: CGFloat = 3.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    // MARK: Overriding

    override var intrinsicContentSize: CGSize {
        let titleSize = titleLabel.intrinsicContentSize
        let subtitleSize = subtitleView.intrinsicContentSize

        let width = max(titleSize.width, subtitleSize.width)
        let height = titleSize.height + verticalSpacing + subtitleSize.height

        return CGSize(width: width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let titleSize = titleLabel.intrinsicContentSize
        let subtitleSize = subtitleView.intrinsicContentSize

        titleLabel.frame = CGRect(x: bounds.minX,
                                  y: bounds.minY,
                                  width: titleSize.width,
                                  height: titleSize.height)

        subtitleView.frame = CGRect(x: bounds.minX,
                                    y: titleLabel.frame.maxY + verticalSpacing,
                                    width: subtitleSize.width,
                                    height: subtitleSize.height)
    }
}
