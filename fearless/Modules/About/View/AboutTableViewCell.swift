import SnapKit
import UIKit

final class AboutTableViewCell: UITableViewCell {
    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSmallArrow()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    // MARK: - Constructors

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        // A multiline label needs the final row width before UIKit measures its height.
        // Otherwise long localized titles can retain a one-line estimate at large type.
        let accessoryWidth = arrowImageView.image?.size.width ?? 0
        let textWidth = max(
            1,
            targetSize.width - 2 * UIConstants.bigOffset - 24
                - 2 * UIConstants.accessoryItemsSpacing - accessoryWidth
        )
        titleLabel.preferredMaxLayoutWidth = textWidth
        descriptionLabel.preferredMaxLayoutWidth = textWidth
        return super.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
    }

    // MARK: - Public methods

    func bind(viewModel: AboutViewModel) {
        titleLabel.text = viewModel.title
        descriptionLabel.text = viewModel.subtitle
        iconImageView.image = viewModel.icon
    }

    // MARK: - Private methods

    private func configure() {
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellSelection()!
        self.selectedBackgroundView = selectedBackgroundView
    }

    private func setupLayout() {
        let separatorView = UIFactory.default.createSeparatorView()
        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        contentView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.separatorHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview()
        }

        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }

        let textStackView = UIFactory.default.createVerticalStackView(spacing: 1)
        contentView.addSubview(textStackView)
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(descriptionLabel)
        textStackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview().inset(7)
        }

        contentView.addSubview(arrowImageView)
        arrowImageView.snp.makeConstraints { make in
            make.size.equalTo(arrowImageView.image?.size ?? CGSize(width: 8, height: 12))
            make.centerY.equalToSuperview()
            make.leading.equalTo(textStackView.snp.trailing).offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }
    }
}
