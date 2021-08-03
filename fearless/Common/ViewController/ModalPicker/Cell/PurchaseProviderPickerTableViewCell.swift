import UIKit

class PurchaseProviderPickerTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = IconWithTitleViewModel

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var checkmarkImageView: UIImageView!

    var checkmarked: Bool = false

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        iconImageView.image = model.icon
    }
}
