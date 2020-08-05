import UIKit

class TitleWithSubtitleTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = TitleWithSubtitleViewModel

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet private var checkmarkImageView: UIImageView!

    var checkmarked: Bool {
        get {
            !checkmarkImageView.isHidden
        }

        set {
            checkmarkImageView.isHidden = !newValue
        }
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
    }
}
