import UIKit

final class StakingBondMoreViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let accountView: DetailsTriangularedView = UIFactory.default.createAccountView(for: .options, filled: true)
    let collatorView: DetailsTriangularedView = UIFactory.default.createAccountView(for: .options, filled: true)

    let amountInputView: AmountInputView = {
        let view = UIFactory().createAmountInputView(filled: false)
        return view
    }()
    
    let hintView: IconDetailsView = {
        let view = IconDetailsView()
        view.iconWidth = 24.0
        view.imageView.contentMode = .top
        view.imageView.image = R.image.iconGeneralReward()
        return view
    }()

    let networkFeeView: NetworkFeeConfirmView = UIFactory().createNetworkFeeConfirmView()

    let actionButton: TriangularedButton = {
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
        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(contentView)

        contentView.stackView.addArrangedSubview(collatorView)
        contentView.stackView.addArrangedSubview(accountView)
        contentView.stackView.addArrangedSubview(amountInputView)
        contentView.stackView.addArrangedSubview(networkFeeView)

        collatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(52)
        }

        accountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(52)
        }

        amountInputView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(72)
        }

        networkFeeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).inset(UIConstants.bigOffset)
        }

        accountView.isHidden = true
        collatorView.isHidden = true
    }
}
