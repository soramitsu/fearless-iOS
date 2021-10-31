import UIKit

class EtheriumAddressForRewardView: UIView {
    let etheriumAddressView = CommonInputView()

    let etheriumHintView = HintView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setupLayout()
    }

    private func setupLayout() {
        addSubview(etheriumAddressView)
        etheriumAddressView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
        }

        addSubview(etheriumHintView)

        etheriumHintView.snp.makeConstraints { make in
            make.top.equalTo(etheriumAddressView.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
        }
    }
}
