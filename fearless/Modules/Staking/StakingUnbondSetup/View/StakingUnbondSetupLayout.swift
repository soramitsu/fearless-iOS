import UIKit
import SnapKit

final class StakingUnbondSetupLayout: UIView {
    enum Constants {
        static let hintsSpacing: CGFloat = 9
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: UIConstants.bigOffset, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let accountView: DetailsTriangularedView = UIFactory.default.createAccountView(for: .options, filled: true)
    let collatorView: DetailsTriangularedView = UIFactory.default.createAccountView(for: .options, filled: true)

    let amountInputView = AmountInputViewV2()

    let networkFeeFooterView: NetworkFeeFooterView = UIFactory().createNetworkFeeFooterView()

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

        backgroundColor = R.color.colorBlack()!

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(feeViewModel: NetworkFeeFooterViewModelProtocol) {
        let balanceViewModel: BalanceViewModelProtocol = feeViewModel.balanceViewModel.value(for: locale)
        networkFeeFooterView.actionTitle = feeViewModel.actionTitle
        networkFeeFooterView.bindBalance(viewModel: balanceViewModel)
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

        amountInputView.locale = locale
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.stackView.addArrangedSubview(collatorView)
        contentView.stackView.addArrangedSubview(accountView)

        collatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: collatorView)

        accountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: accountView)

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

        contentView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(networkFeeFooterView.snp.top).inset(UIConstants.bigOffset)
        }

        accountView.isHidden = true
        collatorView.isHidden = true
    }
}
