import UIKit

final class StakingBondMoreViewLayout: UIView {
    let amountInputView: AmountInputView = {
        let view = UIFactory().createAmountInputView(filled: false)
        return view
    }()

    let networkFeeView = NetworkFeeView()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
        applyLocalization()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        networkFeeView.locale = locale
        continueButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
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

        addSubview(networkFeeView)
        networkFeeView.snp.makeConstraints { make in
            make.top.equalTo(amountInputView.snp.bottom).offset(UIConstants.horizontalInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
