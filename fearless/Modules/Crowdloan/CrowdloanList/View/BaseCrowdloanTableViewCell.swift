import UIKit

class BaseCrowdloanTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        return label
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    let progressLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p2Paragraph
        return label
    }()

    let mainStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.distribution = .fill
        view.alignment = .leading
        return view
    }()

    let titleStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fill
        view.alignment = .center
        return view
    }()

    private(set) var contributionLabel: UILabel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
    }

    func setupLayout() {
        contentView.addSubview(iconImageView)

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(CrowdloanViewConstants.iconSize)
            make.top.equalToSuperview().inset(11)
        }

        contentView.addSubview(mainStackView)

        mainStackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.horizontalInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(6.0)
            make.bottom.equalToSuperview().inset(12.0)
        }

        mainStackView.addArrangedSubview(titleStackView)

        titleStackView.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }

        titleStackView.addArrangedSubview(titleLabel)

        mainStackView.addArrangedSubview(detailsLabel)
        mainStackView.setCustomSpacing(8.0, after: detailsLabel)

        mainStackView.addArrangedSubview(progressLabel)
    }

    func showContributionLabel() {
        guard contributionLabel == nil else {
            return
        }

        let label = UILabel()
        label.font = .p2Paragraph

        mainStackView.addArrangedSubview(label)
        mainStackView.setCustomSpacing(8.0, after: progressLabel)

        contributionLabel = label
    }

    func hideContributionLabel() {
        guard let label = contributionLabel else {
            return
        }

        mainStackView.removeArrangedSubview(label)
        mainStackView.setCustomSpacing(0.0, after: progressLabel)

        label.removeFromSuperview()

        contributionLabel = nil
    }
}
