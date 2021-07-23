import UIKit
import SoraUI
import SoraFoundation

class YourValidatorListWarningSectionView: YourValidatorListStatusSectionView {
    let hintBorderView = UIFactory.default.createBorderedContainerView()

    let hintView: HintView = {
        let view = UIFactory.default.createHintView()
        view.iconView.image = R.image.iconWarning()
        return view
    }()

    override func setupLayout() {
        super.setupLayout()

        mainStackView.insertArranged(view: hintBorderView, before: statusView)

        hintBorderView.addSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(16.0)
        }

        mainStackView.setCustomSpacing(16.0, after: hintBorderView)
    }

    func bind(warningText: String) {
        hintView.titleLabel.text = warningText
    }
}
