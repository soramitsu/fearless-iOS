import UIKit
import SnapKit

final class AboutTableViewCell: UITableViewCell {
    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
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
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(textStackView.snp.trailing).offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }
    }
}
