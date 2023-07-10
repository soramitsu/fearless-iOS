import UIKit
import SoraUI

final class ProfileTableViewCell: UITableViewCell {
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var iconSmallArrow: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet var switcher: UISwitch!
    @IBOutlet var accessoryImageView: UIImageView!
    private(set) var viewModel: ProfileOptionViewModelProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellSelection()!
        self.selectedBackgroundView = selectedBackgroundView
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconSmallArrow.isHidden = false
        subtitleLabel.isHidden = false
        switcher.isHidden = true
    }

    func bind(viewModel: ProfileOptionViewModelProtocol) {
        self.viewModel = viewModel

        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title

        subtitleLabel.text = viewModel.accessoryTitle

        accessoryImageView.isHidden = viewModel.accessoryImage == nil
        accessoryImageView.image = viewModel.accessoryImage

        guard case let .switcher(isOn) = viewModel.accessoryType else {
            switcher.isHidden = true
            return
        }

        iconSmallArrow.isHidden = true
        subtitleLabel.isHidden = true
        switcher.isHidden = false
        switcher.isOn = isOn
    }
}
