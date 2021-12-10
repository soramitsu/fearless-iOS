import UIKit

class LockedBalanceMultiValueView: TitleMultiValueView {
    let button: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfoFilled(), for: .normal)
        return button
    }()

    override func setupLayout() {
        super.setupLayout()

        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing)
            make.centerY.equalToSuperview()
            make.size.equalTo(30)
        }

        valueTop.snp.remakeConstraints { make in
            make.leading.greaterThanOrEqualTo(button.snp.trailing)
            make.trailing.equalToSuperview()
            make.bottom.equalTo(self.snp.centerY)
        }

        valueBottom.snp.remakeConstraints { make in
            make.leading.greaterThanOrEqualTo(valueTop.snp.leading)
            make.trailing.equalToSuperview()
            make.top.equalTo(self.snp.centerY)
        }

        borderView.isHidden = true
    }
}
