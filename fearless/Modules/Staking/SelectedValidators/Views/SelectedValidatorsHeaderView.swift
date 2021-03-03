import UIKit

final class SelectedValidatorsHeaderView: UIView {
    @IBOutlet private var titleLabel: UILabel!

    func bind(title: String) {
        titleLabel.text = title
    }
}
