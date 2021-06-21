import UIKit

final class ActiveCrowdloanTableViewCell: BaseCrowdloanTableViewCell {
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

    private var viewModel: ActiveCrowdloanViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.iconViewModel.cancel(on: iconImageView)
        viewModel = nil

        iconImageView.image = nil
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        applyStyle()
    }

    private func applyStyle() {
        titleLabel.textColor = R.color.colorWhite()
        titleLabel.font = .p1Paragraph

        detailsLabel.textColor = R.color.colorLightGray()
        detailsLabel.font = .p2Paragraph
        detailsLabel.lineBreakMode = .byTruncatingMiddle

        progressLabel.textColor = R.color.colorWhite()
        progressLabel.font = .p2Paragraph
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
            showContributionLabel()

            contributionLabel?.text = contribution
        } else {
            hideContributionLabel()
        }

        viewModel.iconViewModel.loadImage(
            on: iconImageView,
            targetSize: CrowdloanViewConstants.iconSize,
            animated: true
        )
    }

    override func setupLayout() {
        super.setupLayout()

        titleStackView.addArrangedSubview(timeLabel)
        titleStackView.addArrangedSubview(navigationImageView)

        navigationImageView.snp.makeConstraints { make in
            make.size.equalTo(24)
        }
    }

    override func showContributionLabel() {
        super.showContributionLabel()

        contributionLabel?.textColor = R.color.colorWhite()
    }
}
