import UIKit

final class ActiveCrowdloanTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        label.textAlignment = .left
        return label
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let timeLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p3Paragraph
        label.textAlignment = .right
        return label
    }()

    let navigationImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSmallArrow()
        imageView.contentMode = .center
        return imageView
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
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
        view.spacing = 8
        return view
    }()

    private(set) var contributionLabel: UILabel?

    private var viewModel: ActiveCrowdloanViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.iconViewModel.cancel(on: iconImageView)
        viewModel = nil

        iconImageView.image = nil
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ActiveCrowdloanViewModel) {
        self.viewModel = viewModel

        titleLabel.text = viewModel.title

        switch viewModel.description {
        case let .address(address):
            detailsLabel.numberOfLines = 1
            detailsLabel.text = address
        case let .text(text):
            detailsLabel.numberOfLines = 0
            detailsLabel.text = text
        }

        progressLabel.text = viewModel.progress
        timeLabel.text = viewModel.timeleft

        if let contribution = viewModel.contribution {
            insertContributionIfNeeded()

            contributionLabel?.text = contribution
        } else {
            removeContributionIfNeeded()
        }

        viewModel.iconViewModel.loadImage(
            on: iconImageView,
            targetSize: CrowdloanViewConstants.iconSize,
            animated: true
        )
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

    private func setupLayout() {
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
        titleStackView.addArrangedSubview(timeLabel)
        titleStackView.addArrangedSubview(navigationImageView)

        navigationImageView.snp.makeConstraints { make in
            make.size.equalTo(24)
        }

        mainStackView.addArrangedSubview(detailsLabel)
        mainStackView.setCustomSpacing(8.0, after: detailsLabel)

        mainStackView.addArrangedSubview(progressLabel)
    }

    private func insertContributionIfNeeded() {
        guard contributionLabel == nil else {
            return
        }

        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p2Paragraph

        mainStackView.addArrangedSubview(label)
        mainStackView.setCustomSpacing(8.0, after: progressLabel)

        contributionLabel = label
    }

    private func removeContributionIfNeeded() {
        guard let label = contributionLabel else {
            return
        }

        mainStackView.removeArrangedSubview(label)
        mainStackView.setCustomSpacing(0.0, after: progressLabel)

        label.removeFromSuperview()

        contributionLabel = nil
    }
}
