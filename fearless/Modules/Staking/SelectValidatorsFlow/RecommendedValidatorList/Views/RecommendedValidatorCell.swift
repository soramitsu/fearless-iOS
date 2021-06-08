import UIKit
import FearlessUtils

final class RecommendedValidatorCell: UITableViewCell {
    @IBOutlet private var iconView: PolkadotIconView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorHighlightedPink()
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(viewModel: RecommendedValidatorViewModelProtocol) {
        iconView.bind(icon: viewModel.icon)
        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.details
    }
}
