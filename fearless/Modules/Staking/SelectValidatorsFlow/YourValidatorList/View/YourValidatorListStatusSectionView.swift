import UIKit
import SoraUI
import SoraFoundation

class YourValidatorListStatusSectionView: YourValidatorListDescSectionView {
    let statusView: IconTitleValueView = {
        let view = UIFactory.default.createIconTitleValueView()
        view.titleLabel.font = .h4Title
        view.titleLabel.textColor = R.color.colorWhite()
        view.valueLabel.font = .capsTitle
        view.valueLabel.textColor = R.color.colorLightGray()
        view.borderView.borderType = .none
        return view
    }()

    override func setupLayout() {
        super.setupLayout()

        mainStackView.insertArranged(view: statusView, before: descriptionLabel)

        statusView.snp.makeConstraints { make in
            make.height.equalTo(20.0)
        }

        mainStackView.setCustomSpacing(15, after: statusView)
    }

    func bind(icon: UIImage, title: String, value: String) {
        statusView.imageView.image = icon
        statusView.titleLabel.text = title
        statusView.valueLabel.text = value
    }
}
