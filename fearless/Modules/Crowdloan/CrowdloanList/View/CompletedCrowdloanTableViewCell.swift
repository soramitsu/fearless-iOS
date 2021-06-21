import UIKit

final class CompletedCrowdloanTableViewCell: BaseCrowdloanTableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        applyStyle()
    }

    private func applyStyle() {
        titleLabel.textColor = R.color.colorStrokeGray()
        titleLabel.font = .p1Paragraph

        detailsLabel.textColor = R.color.colorStrokeGray()
        detailsLabel.font = .p2Paragraph
        detailsLabel.lineBreakMode = .byTruncatingMiddle

        progressLabel.textColor = R.color.colorStrokeGray()
        progressLabel.font = .p2Paragraph

        selectionStyle = .none
    }

    private var viewModel: CompletedCrowdloanViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.iconViewModel.cancel(on: iconImageView)
        viewModel = nil

        iconImageView.image = nil
    }

    func bind(viewModel: CompletedCrowdloanViewModel) {
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

        if let contribution = viewModel.contribution {
            showContributionLabel()

            contributionLabel?.text = contribution
        } else {
            hideContributionLabel()
        }

        progressLabel.text = viewModel.progress

        viewModel.iconViewModel.loadImage(
            on: iconImageView,
            targetSize: CrowdloanViewConstants.iconSize,
            animated: true
        )
    }

    override func showContributionLabel() {
        super.showContributionLabel()

        contributionLabel?.textColor = R.color.colorStrokeGray()
    }
}
