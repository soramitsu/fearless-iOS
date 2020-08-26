import UIKit

class IconWithTitleTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = IconWithTitleViewModel

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var checkmarkImageView: UIImageView!

    var checkmarked: Bool {
        get {
            !checkmarkImageView.isHidden
        }

        set {
            checkmarkImageView.isHidden = !newValue
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorDarkBlue()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        iconImageView.image = model.icon
    }
}
