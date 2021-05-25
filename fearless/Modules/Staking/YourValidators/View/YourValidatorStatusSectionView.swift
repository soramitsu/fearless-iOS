import UIKit

class YourValidatorStatusSectionView: StatusSectionView {
    func bind(title: String, for status: YourValidatorsSectionStatus) {
        titleLabel.text = title.uppercased()

        let color: UIColor = {
            switch status {
            case .active:
                return R.color.colorGreen()!
            case .slashed:
                return R.color.colorRed()!
            case .inactive, .waiting, .pending:
                return R.color.colorLightGray()!
            }
        }()

        titleLabel.textColor = color
        indicatorView.fillColor = color
    }
}
