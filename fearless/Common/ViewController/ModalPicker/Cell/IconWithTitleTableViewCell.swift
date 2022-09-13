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
        selectedBackgroundView.backgroundColor = R.color.colorPink()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(model: Model) {
        titleLabel.text = model.title

        if let remoteImageViewModel = model.remoteImageViewModel {
            remoteImageViewModel.loadImage(
                on: iconImageView,
                targetSize: iconImageView.frame.size,
                animated: true
            )
        } else {
            iconImageView.image = model.icon
        }
    }
}
