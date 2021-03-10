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
        detailsView.title = model.name
        detailsView.subtitle = model.address

        detailsView.iconImage = model.icon

        setNeedsLayout()
    }
}
