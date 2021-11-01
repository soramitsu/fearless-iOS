import UIKit

class EthereumAddressForRewardView: UIView {
    let ethereumAddressView = CommonInputView()

    let ethereumHintView = HintView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupLayout()
    }

    private func setupLayout() {
        addSubview(ethereumAddressView)
        ethereumAddressView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
        }

        addSubview(ethereumHintView)

        ethereumHintView.snp.makeConstraints { make in
            make.top.equalTo(ethereumAddressView.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
        }
    }
}
