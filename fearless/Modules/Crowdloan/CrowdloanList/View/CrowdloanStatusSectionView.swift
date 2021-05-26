import UIKit

class CrowdloanStatusSectionView: StatusSectionView {
    func bind(title: String, status: CrowdloanStatus) {
        titleLabel.text = title.uppercased()

        let color: UIColor = {
            switch status {
            case .active:
                return R.color.colorGreen()!
            case .completed:
                return R.color.colorLightGray()!
            }
        }()

        titleLabel.textColor = color
        indicatorView.fillColor = color
    }
}
