import UIKit

final class AboutDetailsCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet private var iconView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorCellSelection()!
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(title: String, subtitle: String, icon: UIImage?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        iconView.image = icon
    }
}
