import UIKit

final class ValidatorInfoHeaderView: UIView {
    @IBOutlet private var titleLabel: UILabel!

    func bind(title: String) {
        titleLabel.text = title
    }
}
