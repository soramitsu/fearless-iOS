import UIKit
import FearlessUtils
import SoraUI

protocol AccountTableViewCellDelegate: class {
    func didSelectInfo(_ cell: AccountTableViewCell)
}

final class AccountTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var iconView: PolkadotIconView!
    @IBOutlet private var infoButton: RoundedButton!
    @IBOutlet private var selectionImageView: UIImageView!

    weak var delegate: AccountTableViewCellDelegate?

    func setReordering(_ reordering: Bool, animated: Bool) {
        let closure = {
            self.infoButton.alpha = reordering ? 0.0 : 1.0
        }

        if animated {
            BlockViewAnimator().animate(block: closure, completionBlock: nil)
        } else {
            closure()
        }

        if reordering {
            recolorReoderControl(R.color.colorWhite()!)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorDarkBlue()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView

        showsReorderControl = false
    }

    func bind(viewModel: ManagedAccountViewModelItem) {
        titleLabel.text = viewModel.name
        detailsLabel.text = viewModel.address

        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        selectionImageView.isHidden = !viewModel.isSelected
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.frame = CGRect(origin: .zero, size: bounds.size)
    }

    // MARK: Private

    @IBAction private func actionInfo() {
        delegate?.didSelectInfo(self)
    }
}
