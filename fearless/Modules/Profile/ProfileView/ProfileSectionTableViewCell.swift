import UIKit

final class ProfileSectionTableViewCell: UITableViewCell {
    @IBOutlet private(set) var titleLabel: UILabel!

    @IBOutlet private var leading: NSLayoutConstraint!
    @IBOutlet private var trailing: NSLayoutConstraint!
    @IBOutlet private var centerY: NSLayoutConstraint!

    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0) {
        didSet {
            updateContentInsets()
            setNeedsLayout()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        updateContentInsets()
    }

    private func updateContentInsets() {
        leading.constant = contentInsets.left
        trailing.constant = -contentInsets.right
        centerY.constant = contentInsets.top - contentInsets.bottom
    }
}
