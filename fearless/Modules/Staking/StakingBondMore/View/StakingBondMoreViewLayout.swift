import UIKit

final class StakingBondMoreViewLayout: UIView {
    let amountInputView: AmountInputView = {
        let amountInputView = AmountInputView()
        amountInputView.fillColor = R.color.colorBlack()!
        amountInputView.strokeColor = R.color.colorGray()!
        amountInputView.titleColor = R.color.colorLightGray()!
        amountInputView.borderWidth = 1
        return amountInputView
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let separator = UIView.createSeparator(color: R.color.colorDarkGray())
        addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.separatorHeight)
        }

        addSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom).offset(UIConstants.horizontalInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
