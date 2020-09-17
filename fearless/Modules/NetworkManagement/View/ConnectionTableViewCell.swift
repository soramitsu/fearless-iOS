import UIKit
import SoraUI

protocol ConnectionTableViewCellDelegate: class {
    func didSelectInfo(_ cell: ConnectionTableViewCell)
}

final class ConnectionTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var iconView: UIImageView!
    @IBOutlet private var infoButton: RoundedButton!
    @IBOutlet private var selectionImageView: UIImageView!

    weak var delegate: ConnectionTableViewCellDelegate?

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

    func bind(viewModel: ManagedConnectionViewModel) {
        titleLabel.text = viewModel.name
        detailsLabel.text = viewModel.identifier
        iconView.image = viewModel.type.icon

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
