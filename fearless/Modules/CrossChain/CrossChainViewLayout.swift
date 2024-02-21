import UIKit
import SnapKit

final class CrossChainViewLayout: UIView {
    enum LayoutConstants {
        static let verticalOffset: CGFloat = 12
        static let stackSubviewHeight: CGFloat = 64
        static let networkFeeViewHeight: CGFloat = 50
        static let contentViewLayoutMargins = UIEdgeInsets(
            top: 24.0,
            left: 0.0,
            bottom: 0.0,
            right: 0.0
        )
    }

    var keyboardAdoptableConstraint: Constraint?

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack02()
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
        view.stackView.layoutMargins = LayoutConstants.contentViewLayoutMargins
        view.stackView.spacing = LayoutConstants.verticalOffset
        return view
    }()

    let originSelectNetworkView = UIFactory.default.createNetworkView(selectable: false)
    let amountView = SelectableAmountInputView(type: .send)
    let destSelectNetworkView = UIFactory.default.createNetworkView(selectable: true)
    let searchView = SearchTriangularedView(withPasteButton: true)

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

    let myWalletsButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.fearlessRoundedIconSmall()
        return button
    }()

    let originNetworkFeeView = UIFactory.default.createMultiView()
    let destinationNetworkFeeView = UIFactory.default.createMultiView()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    private let bottomContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    let sendAllContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()

    let sendAllLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let sendAllSwitch: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorPink()
        return switchView
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        applyLocalization()
        backgroundColor = R.color.colorBlack19()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func bind(originFeeViewModel: BalanceViewModelProtocol?) {
        originNetworkFeeView.bindBalance(viewModel: originFeeViewModel)
    }

    func bind(destinationFeeViewModel: BalanceViewModelProtocol?) {
        destinationNetworkFeeView.bindBalance(viewModel: destinationFeeViewModel)
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        amountView.bind(viewModel: assetViewModel)
    }

    func bind(originalSelectNetworkViewModel: SelectNetworkViewModel) {
        originSelectNetworkView.subtitle = originalSelectNetworkViewModel.chainName
        originalSelectNetworkViewModel.iconViewModel?.cancel(on: originSelectNetworkView.iconView)
        originSelectNetworkView.iconView.image = nil
        originalSelectNetworkViewModel
            .iconViewModel?
            .loadAmountInputIcon(on: originSelectNetworkView.iconView, animated: true)
    }

    func bind(destSelectNetworkViewModel: SelectNetworkViewModel) {
        destSelectNetworkView.subtitle = destSelectNetworkViewModel.chainName
        destSelectNetworkViewModel.iconViewModel?.cancel(on: destSelectNetworkView.iconView)
        destSelectNetworkView.iconView.image = nil
        destSelectNetworkViewModel
            .iconViewModel?
            .loadAmountInputIcon(on: destSelectNetworkView.iconView, animated: true)
    }

    func bind(recipientViewModel: RecipientViewModel) {
        searchView.textField.text = recipientViewModel.address
        searchView.updateState(icon: recipientViewModel.icon)
    }

    func switchEnableSendAllVisibility(isVisible: Bool) {
        sendAllContainerView.isHidden = !isVisible
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(bottomContainer)

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

        sendAllContainerView.addSubview(sendAllLabel)
        sendAllLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview().offset(4)
        }

        sendAllContainerView.addSubview(sendAllSwitch)
        sendAllSwitch.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(sendAllLabel.snp.trailing).offset(4)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        bottomContainer.addSubview(sendAllContainerView)
        sendAllContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-UIConstants.bigOffset)
            make.top.equalToSuperview()
        }

        navigationBar.setCenterViews([navigationTitleLabel])
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(actionButton.snp.top).offset(-UIConstants.bigOffset)
        }

        let viewOffset = -2.0 * UIConstants.horizontalInset

        contentView.stackView.addArrangedSubview(originSelectNetworkView)
        originSelectNetworkView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
        }

        contentView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(UIConstants.amountViewV2Height)
        }

        contentView.stackView.addArrangedSubview(destSelectNetworkView)
        destSelectNetworkView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
        }

        contentView.stackView.addArrangedSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
        }

        let commonButtonsContainer = UIFactory
            .default
            .createHorizontalStackView()
        commonButtonsContainer.distribution = .equalCentering

        let leftSideButtonContainer = UIFactory
            .default
            .createHorizontalStackView(spacing: UIConstants.defaultOffset)
        leftSideButtonContainer.alignment = .leading
        leftSideButtonContainer.addArrangedSubview(scanButton)
        leftSideButtonContainer.addArrangedSubview(historyButton)

        commonButtonsContainer.addArrangedSubview(leftSideButtonContainer)
        commonButtonsContainer.addArrangedSubview(myWalletsButton)

        contentView.stackView.addArrangedSubview(commonButtonsContainer)
        commonButtonsContainer.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
        }

        contentView.stackView.addArrangedSubview(originNetworkFeeView)
        originNetworkFeeView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.networkFeeViewHeight)
        }
        contentView.stackView.addArrangedSubview(destinationNetworkFeeView)
        destinationNetworkFeeView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.networkFeeViewHeight)
        }
        contentView.stackView.setCustomSpacing(0, after: originNetworkFeeView)
    }

    private func applyLocalization() {
        amountView.locale = locale
        searchView.locale = locale
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        searchView.textField.attributedPlaceholder = NSAttributedString(
            string: R.string.localizable.searchViewTitle(
                preferredLanguages: locale.rLanguages
            ),
            attributes: [.foregroundColor: R.color.colorAlmostWhite()!]
        )

        scanButton.imageWithTitleView?.title = R.string.localizable.scanQrTitle(
            preferredLanguages: locale.rLanguages
        )

        historyButton.imageWithTitleView?.title = R.string.localizable.walletHistoryTitle_v190(
            preferredLanguages: locale.rLanguages
        )

        myWalletsButton.imageWithTitleView?.title = R.string.localizable.xcmMywalletsButtonTitle(
            preferredLanguages: locale.rLanguages
        )

        navigationTitleLabel.text = R.string.localizable.xcmTitle(preferredLanguages: locale.rLanguages)
        originSelectNetworkView.title = R.string.localizable.xcmOriginNetworkTitle(preferredLanguages: locale.rLanguages)
        destSelectNetworkView.title = R.string.localizable.xcmDestinationNetworkTitle(preferredLanguages: locale.rLanguages)
        originNetworkFeeView.titleLabel.text = R.string.localizable.xcmOriginNetworkFeeTitle(preferredLanguages: locale.rLanguages)
        destinationNetworkFeeView.titleLabel.text = R.string.localizable.xcmDestinationNetworkFeeTitle(preferredLanguages: locale.rLanguages)
        sendAllLabel.text = R.string.localizable.sendAllTitle(preferredLanguages: locale.rLanguages)
    }
}
