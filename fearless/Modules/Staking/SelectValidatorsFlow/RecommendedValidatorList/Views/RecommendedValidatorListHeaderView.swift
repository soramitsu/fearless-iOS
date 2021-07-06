import UIKit

final class RecommendedValidatorListHeaderView: UIView {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!

    func bind(title: String, details: String = "") {
        titleLabel.text = title
        detailsLabel.text = details
    }
}
