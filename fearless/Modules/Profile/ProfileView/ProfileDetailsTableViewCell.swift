import UIKit

final class ProfileDetailsTableViewCell: UITableViewCell {
    @IBOutlet private(set) var detailsView: ProfileView!

    override func awakeFromNib() {
        super.awakeFromNib()

        detailsView.titleLabel.lineBreakMode = .byTruncatingMiddle
        detailsView.subtitleLabel.lineBreakMode = .byTruncatingMiddle
    }
}
