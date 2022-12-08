import SoraUI
import SnapKit

final class SubtitleContentView: UIView {
    enum Constants {
        static let verticalSpacing: CGFloat = 3.0
        static let horizontalSubtitleSpacing: CGFloat = 8.0
        static let imageSize: CGFloat = 15.0
    }

    let titleLabel = UILabel()
    let subtitleImageView = UIImageView()
    let subtitleLabelView = UILabel()
    let subtitleStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fill
        view.spacing = 4
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
        setupLayout()
    }

    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        let titleSize = titleLabel.intrinsicContentSize
        var subtitleSize = subtitleLabelView.intrinsicContentSize

        subtitleSize.width += Constants.imageSize + Constants.horizontalSubtitleSpacing
        subtitleSize.height = max(Constants.imageSize, subtitleSize.height)

        let width = max(titleSize.width, subtitleSize.width)
        let height = titleSize.height + Constants.verticalSpacing + subtitleSize.height

        return CGSize(width: width, height: height)
    }

    private func configure() {
        addSubview(titleLabel)

        subtitleStackView.addArrangedSubview(subtitleImageView)
        subtitleStackView.addArrangedSubview(subtitleLabelView)
        addSubview(subtitleStackView)
    }

    func setupLayout() {
        subtitleImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.imageSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        subtitleStackView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.verticalSpacing)
        }
    }
}
