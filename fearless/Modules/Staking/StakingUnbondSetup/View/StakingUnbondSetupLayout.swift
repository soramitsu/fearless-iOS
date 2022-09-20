import UIKit
import SnapKit

final class StakingUnbondSetupLayout: UIView {
    enum Constants {
        static let hintsSpacing: CGFloat = 9
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        bar.backButton.layer.cornerRadius = bar.backButton.frame.size.height / 2
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: UIConstants.bigOffset, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let accountView: DetailsTriangularedView = UIFactory.default.createAccountView(for: .options, filled: true)
    let collatorView: DetailsTriangularedView = UIFactory.default.createAccountView(for: .options, filled: true)

    let amountInputView: AmountInputView = UIFactory.default.createAmountInputView(filled: true)

    let networkFeeFooterView: CleanNetworkFeeFooterView = UIFactory().createCleanNetworkFeeFooterView()
    private(set) var hintViews: [UIView] = []

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack19()!

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(feeViewModel: NetworkFeeFooterViewModelProtocol?) {
        networkFeeFooterView.actionTitle = feeViewModel?.actionTitle
        networkFeeFooterView.bindBalance(viewModel: feeViewModel?.balanceViewModel.value(for: locale))
        setNeedsLayout()
    }

    func bind(hintViewModels: [TitleIconViewModel]) {
        hintViews.forEach { $0.removeFromSuperview() }

        hintViews = hintViewModels.map { hint in
            let view = IconDetailsView()
            view.iconWidth = UIConstants.iconSize
            view.detailsLabel.text = hint.title
            view.imageView.image = hint.icon
            return view
        }

        for (index, view) in hintViews.enumerated() {
            if index > 0 {
                contentView.stackView.insertArranged(view: view, after: hintViews[index - 1])
            } else {
                contentView.stackView.insertArranged(view: view, after: amountInputView)
            }

            view.snp.makeConstraints { make in
                make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            }

            contentView.stackView.setCustomSpacing(Constants.hintsSpacing, after: view)
        }
    }

    private func applyLocalization() {
        networkFeeFooterView.locale = locale

        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.layer.cornerRadius = navigationBar.backButton.frame.size.height / 2
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)

        contentView.stackView.addArrangedSubview(collatorView)

        collatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: collatorView)

        contentView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.amountViewHeight)
        }

        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: amountInputView)

        addSubview(networkFeeFooterView)
        networkFeeFooterView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(networkFeeFooterView.snp.top).inset(UIConstants.bigOffset)
        }

        accountView.isHidden = true
        collatorView.isHidden = true
    }
}
