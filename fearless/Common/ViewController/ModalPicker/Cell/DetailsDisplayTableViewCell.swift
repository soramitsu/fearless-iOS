import Foundation
import UIKit

final class DetailsDisplayTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    var checkmarked: Bool = false

    typealias Model = TitleWithSubtitleViewModel

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!

    func bind(model: TitleWithSubtitleViewModel) {
        titleLabel.text = model.title
        detailsLabel.text = model.subtitle
    }
}
