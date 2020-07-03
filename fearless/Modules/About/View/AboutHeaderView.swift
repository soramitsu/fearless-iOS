import UIKit

final class AboutHeaderView: UIView {
    @IBOutlet private var titleLabel: UILabel!

    func bind(title: String) {
        titleLabel.text = title
    }
}
