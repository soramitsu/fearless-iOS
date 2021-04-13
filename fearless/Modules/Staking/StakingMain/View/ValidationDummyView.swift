import UIKit

final class ValidationDummyView: LocalizableView {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        applyLocalization()
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .stakingValidatorSummaryTitle(preferredLanguages: locale.rLanguages)
        detailsLabel.text = R.string.localizable
            .stakingValidatorSummaryDescription(preferredLanguages: locale.rLanguages)
    }
}
