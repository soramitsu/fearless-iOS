import UIKit
import SoraFoundation

final class CleanNetworkFeeFooterView: UIView {
    private let contentStackView = UIFactory.default.createVerticalStackView(spacing: 8)

    let tipView = NetworkFeeView()
    var networkFeeView: NetworkFeeView?
    var durationView: TitleValueView?

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

    var actionTitle: LocalizableResource<String>? {
        didSet {
            actionButton.imageWithTitleView?.title = actionTitle?.value(for: locale)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        applyLocalization()
        setupLayout()
    }

    func bindBalance(viewModel: BalanceViewModelProtocol?) {
        if networkFeeView == nil {
            let balanceView = NetworkFeeView()
            contentStackView.insertArranged(view: balanceView, before: actionButton)
            networkFeeView = balanceView
            networkFeeView?.titleLabel.font = .p2Paragraph
            networkFeeView?.titleLabel.textColor = R.color.colorStrokeGray()
            networkFeeView?.borderType = .none
            networkFeeView?.locale = locale
            networkFeeView?.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.actionHeight)
            }
        }
        networkFeeView?.bind(viewModel: viewModel)
    }

    func bindDuration(viewModel: LocalizableResource<TitleWithSubtitleViewModel>) {
        if durationView == nil {
            let durView = UIFactory.default.createTitleValueView()
            contentStackView.insertArranged(view: durView, before: actionButton)
            durationView = durView
            durView.borderView.isHidden = true
            durationView?.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.actionHeight)
            }
        }
        durationView?.titleLabel.text = viewModel.value(for: locale).title
        durationView?.valueLabel.text = viewModel.value(for: locale).subtitle
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        actionButton.imageWithTitleView?.title = actionTitle?.value(for: locale) ?? R.string.localizable
            .commonConfirm(preferredLanguages: locale.rLanguages)
        tipView.titleLabel.text = R.string.localizable.walletSendTipTitle(preferredLanguages: locale.rLanguages)
        networkFeeView?.locale = locale
    }

    private func setupLayout() {
        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        tipView.borderType = .none
        contentStackView.addArrangedSubview(tipView)
        contentStackView.addArrangedSubview(actionButton)
        tipView.isHidden = true // by default, because this view is being used among other screens but send confirmatio

        actionButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
