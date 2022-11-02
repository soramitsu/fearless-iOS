import UIKit
import FearlessUtils

protocol RecommendedValidatorCellDelegate: AnyObject {
    func didTapInfoButton(in cell: RecommendedValidatorCell)
}

final class RecommendedValidatorCell: UITableViewCell {
    @IBOutlet private var iconView: PolkadotIconView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet var selectedIconImageView: UIImageView!
    @IBOutlet var infoButton: UIButton!

    weak var delegate: RecommendedValidatorCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorHighlightedPink()
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(viewModel: RecommendedValidatorViewModelProtocol) {
        selectedIconImageView.isHidden = !viewModel.isSelected
        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        titleLabel.text = viewModel.title
        detailsLabel.attributedText = viewModel.detailsAttributedString
    }

    @IBAction func infoButtonClicked() {
        delegate?.didTapInfoButton(in: self)
    }
}
