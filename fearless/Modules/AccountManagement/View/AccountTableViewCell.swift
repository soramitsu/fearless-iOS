import UIKit
import FearlessUtils
import SoraUI

final class AccountTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var iconView: PolkadotIconView!
    @IBOutlet private var infoButton: RoundedButton!
    @IBOutlet private var selectionImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorDarkBlue()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(viewModel: ManagedAccountViewModelItem) {
        titleLabel.text = viewModel.name
        detailsLabel.text = viewModel.address

        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        selectionImageView.isHidden = !viewModel.isSelected
    }
}
