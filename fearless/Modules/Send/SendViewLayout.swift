import UIKit
import SnapKit

final class SendViewLayout: UIView {
    enum LayoutConstants {
        static let verticalOffset: CGFloat = 25
        static let stackActionHeight: CGFloat = 32
        static let stackViewSpacing: CGFloat = 12
        static let bottomContainerHeight: CGFloat = 120
        static let stackSubviewHeight: CGFloat = 64
        static let optionsImageSize: CGFloat = 16
    }

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = LayoutConstants.verticalOffset
        return view
    }()

    let amountView = SelectableAmountInputView()
    let selectNetworkView = UIFactory.default.createSelectNetworkView()
    let scamWarningView: ScamWarningExpandableView = {
        let view = ScamWarningExpandableView()
        view.isHidden = true
        return view
    }()

    let feeView: NetworkFeeView = {
        let view = UIFactory.default.createNetworkFeeView()
        view.borderView.isHidden = true
        view.isHidden = true
        return view
    }()

    let tipView: NetworkFeeView = {
        let view = UIFactory.default.createNetworkFeeView()
        view.borderView.isHidden = true
        view.isHidden = true
        return view
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    private let bottomContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let optionsStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fillProportionally
        view.spacing = 12
        view.isUserInteractionEnabled = true
        return view
    }()

    let scanButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.iconScanQr()
        return button
    }()

    let historyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.iconHistory()
        return button
    }()

    let pasteButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.iconCopy()
        return button
    }()

    let searchView = SearchTriangularedView(frame: .zero)

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    var keyboardAdoptableConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack19()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        amountView.bind(viewModel: assetViewModel)
    }

    func bind(selectNetworkviewModel: SelectNetworkViewModel) {
        selectNetworkView.subtitle = selectNetworkviewModel.chainName
        selectNetworkviewModel.iconViewModel?.cancel(on: selectNetworkView.iconView)
        selectNetworkView.iconView.image = nil
        selectNetworkviewModel.iconViewModel?.loadAmountInputIcon(on: selectNetworkView.iconView, animated: true)
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.bind(viewModel: feeViewModel)
        feeView.isHidden = (feeViewModel == nil)
    }

    func bind(tipViewModel: TipViewModel?) {
        tipView.bind(viewModel: tipViewModel?.balanceViewModel)
        tipView.isHidden =
            !(tipViewModel?.tipRequired == true && tipViewModel?.balanceViewModel != nil)
    }

    func bind(scamInfo: ScamInfo?) {
        guard let scamInfo = scamInfo else {
            scamWarningView.isHidden = true
            return
        }
        scamWarningView.isHidden = false

        scamWarningView.bind(scamInfo: scamInfo, assetName: amountView.symbol ?? "")
    }

    func bind(viewModel: RecipientViewModel) {
        searchView.textField.text = viewModel.address
        searchView.updateState(icon: viewModel.icon)
    }
}

private extension SendViewLayout {
    func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(bottomContainer)

        navigationBar.setCenterViews([navigationTitleLabel])
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(bottomContainer.snp.top).offset(-UIConstants.bigOffset)
        }

        let viewOffset = -2.0 * UIConstants.horizontalInset

        contentView.stackView.addArrangedSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
        }

        contentView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(UIConstants.amountViewV2Height)
        }

        contentView.stackView.addArrangedSubview(selectNetworkView)
        selectNetworkView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
        }

        contentView.stackView.addArrangedSubview(scamWarningView)
        scamWarningView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
        }

        contentView.stackView.addArrangedSubview(feeView) { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(viewOffset)
        }

        contentView.stackView.addArrangedSubview(tipView) { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(viewOffset)
        }

        bottomContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            keyboardAdoptableConstraint =
                make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset).constraint
        }

        bottomContainer.addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }

        optionsStackView.addArrangedSubview(scanButton)
        optionsStackView.addArrangedSubview(historyButton)
        optionsStackView.addArrangedSubview(pasteButton)

        bottomContainer.addSubview(optionsStackView)
        optionsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.stackActionHeight)
            make.top.equalToSuperview()
        }
    }

    func applyLocalization() {
        feeView.locale = locale
        amountView.locale = locale
        scamWarningView.locale = locale

        searchView.textField.attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.searchTextfieldPlaceholder(
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorAlmostWhite()!]
        )
        searchView.titleLabel.text = R.string.localizable.searchViewTitle(
            preferredLanguages: locale.rLanguages
        )

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonPreview(preferredLanguages: locale.rLanguages)

        tipView.titleLabel.text = R.string.localizable.walletSendTipTitle(preferredLanguages: locale.rLanguages)

        scanButton.imageWithTitleView?.title = R.string.localizable.scanQrTitle(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        historyButton.imageWithTitleView?.title = R.string.localizable.walletHistoryTitle_v190(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        pasteButton.imageWithTitleView?.title = R.string.localizable.commonPaste(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        navigationTitleLabel.text = R.string.localizable
            .sendFundTitle(preferredLanguages: locale.rLanguages)

        selectNetworkView.title = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)
    }
}
