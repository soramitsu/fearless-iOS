import UIKit
import SoraUI

final class ProfileTableViewCell: UITableViewCell {

    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var accessoryRoundView: RoundedButton!

    private(set) var viewModel: ProfileOptionViewModelProtocol?

    func bind(viewModel: ProfileOptionViewModelProtocol) {
        self.viewModel = viewModel

        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title

        accessoryRoundView.imageWithTitleView?.title = viewModel.accessoryTitle
        accessoryRoundView.imageWithTitleView?.iconImage = viewModel.accessoryIcon

        let spacing: CGFloat = (viewModel.accessoryTitle != nil && viewModel.accessoryIcon != nil) ? 6.0 : 0.0
        accessoryRoundView.imageWithTitleView?.spacingBetweenLabelAndIcon = spacing

        accessoryRoundView.isHidden = (viewModel.accessoryTitle == nil && viewModel.accessoryIcon == nil)
        accessoryRoundView.invalidateLayout()
    }
}
