import UIKit
import SoraUI

final class ValidatorInfoTitleSubtitleCell: UITableViewCell {

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellSelection()!
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(title: String?, subtitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    func bind(model: TitleWithSubtitleViewModel) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
    }
}
