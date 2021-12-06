import UIKit

class TwoVerticalLabelView: UIView {
    let titleLabel = UILabel()
    let subtitleLabelView = UILabel()

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
        let subtitleSize = subtitleLabelView.intrinsicContentSize

        let width = max(titleSize.width, subtitleSize.width)
        let height = titleSize.height + verticalSpacing + subtitleSize.height

        return CGSize(width: width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.top.equalToSuperview()
        }

        subtitleLabelView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(verticalSpacing)
            make.bottom.equalToSuperview()
        }
    }
}
