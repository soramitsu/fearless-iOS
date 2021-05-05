import UIKit
import SoraUI

final class ValidatorInfoAccountCell: UITableViewCell {
    @IBOutlet private(set) var detailsView: DetailsTriangularedView!

    override func awakeFromNib() {
        super.awakeFromNib()

        detailsView.titleLabel.lineBreakMode = .byTruncatingMiddle
        detailsView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        detailsView.set(highlighted: highlighted, animated: animated)
    }

    func bind(model: ValidatorInfoAccountViewModelProtocol) {
        if let name = model.name {
            detailsView.title = name
            detailsView.subtitle = model.address
        } else {
            detailsView.layout = .singleTitle
            detailsView.title = model.address
        }

        detailsView.iconImage = model.icon

        setNeedsLayout()
    }
}
