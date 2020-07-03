import UIKit

final class AboutNavigationCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!

    func bind(title: String) {
        titleLabel.text = title
    }
}
