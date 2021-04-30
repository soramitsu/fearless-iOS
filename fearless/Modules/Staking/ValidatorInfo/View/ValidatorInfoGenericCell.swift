import UIKit
import SoraUI

struct ValidatorInfoCellStyle: OptionSet {
    let rawValue: Int

    static let info = ValidatorInfoCellStyle(rawValue: 1 << 0)
    static let warning = ValidatorInfoCellStyle(rawValue: 1 << 1)
    static let balance = ValidatorInfoCellStyle(rawValue: 1 << 2)
    static let web = ValidatorInfoCellStyle(rawValue: 1 << 3)

    static let totalStake: ValidatorInfoCellStyle = [.info, .balance]
    static let oversubscribed: ValidatorInfoCellStyle = [.info, .warning]
}

final class ValidatorInfoGenericCell: UITableViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet private var auxSubtitleLabel: UILabel!
    @IBOutlet private var infoIcon: UIImageView!
    @IBOutlet private var warningIcon: UIImageView!
    @IBOutlet private var arrowIcon: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }

    private func setup() {
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorHighlightedPink()
        self.selectedBackgroundView = selectedBackgroundView

        auxSubtitleLabel.isHidden = true
        infoIcon.isHidden = true
        warningIcon.isHidden = true
        arrowIcon.isHidden = true
    }

    func bind(title: String?, subtitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.textColor = R.color.colorLightGray()!
    }

    func bind(model: TitleWithSubtitleViewModel) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        subtitleLabel.textColor = R.color.colorLightGray()!
    }

    func bind(model: TitleWithSubtitleViewModel, state: ValidatorMyNominationStatus) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle

        switch state {
        case .active: subtitleLabel.textColor = R.color.colorGreen()!
        case .slashed: subtitleLabel.textColor = R.color.colorRed()!
        default: subtitleLabel.textColor = R.color.colorLightGray()!
        }
    }

    func bind(model: StakingAmountViewModel) {
        titleLabel.text = model.title
        subtitleLabel.text = model.balance.amount
        auxSubtitleLabel.text = model.balance.price
        subtitleLabel.textColor = R.color.colorLightGray()!
    }

    func setStyle(_ style: ValidatorInfoCellStyle) {
        infoIcon.isHidden = !style.contains(.info)
        warningIcon.isHidden = !style.contains(.warning)
        auxSubtitleLabel.isHidden = !style.contains(.balance)
        arrowIcon.isHidden = !style.contains(.web)
    }
}
