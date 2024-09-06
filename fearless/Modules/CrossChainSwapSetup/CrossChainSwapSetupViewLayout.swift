import UIKit
import SnapKit

final class CrossChainSwapSetupViewLayout: UIView {
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

    let amountView = SelectableAmountInputView(type: .swapSend)
    let receiveView: SelectableAmountInputView = {
        let view = SelectableAmountInputView(type: .swapReceive)
        view.textField.isUserInteractionEnabled = false
        return view
    }()

    let originNetworkFeeView = createMultiView()
    let minReceivedView = createMultiView()
    let routeView = createMultiView()
    let sendRatioView = createMultiView()
    let receiveRatioView = createMultiView()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
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

    func bind(viewModel: CrossChainSwapViewModel?) {
        [minReceivedView, routeView, sendRatioView, receiveRatioView, originNetworkFeeView].forEach { $0.isHidden = viewModel == nil }

        minReceivedView.bindBalance(viewModel: viewModel?.minimumReceived)
        routeView.valueTop.text = viewModel?.route
        sendRatioView.valueTop.text = viewModel?.sendTokenRatio
        receiveRatioView.valueTop.text = viewModel?.receiveTokenRatio
        sendRatioView.titleLabel.text = viewModel?.sendTokenRatioTitle
        receiveRatioView.titleLabel.text = viewModel?.receiveTokenRatioTitle
        originNetworkFeeView.bindBalance(viewModel: viewModel?.fee)
    }

    func bind(originFeeViewModel: BalanceViewModelProtocol?) {
        originNetworkFeeView.isHidden = originFeeViewModel == nil
        originNetworkFeeView.bindBalance(viewModel: originFeeViewModel)
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        amountView.bind(viewModel: assetViewModel)
    }

    func bind(receiveAssetViewModel: AssetBalanceViewModelProtocol) {
        receiveView.bind(viewModel: receiveAssetViewModel)
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(actionButton)

        actionButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            keyboardAdoptableConstraint =
                make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset).constraint
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

        contentView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
        }

        contentView.stackView.addArrangedSubview(receiveView)
        receiveView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
        }

        contentView.stackView.addArrangedSubview(minReceivedView)
        contentView.stackView.addArrangedSubview(routeView)
        contentView.stackView.addArrangedSubview(sendRatioView)
        contentView.stackView.addArrangedSubview(receiveRatioView)
        contentView.stackView.addArrangedSubview(originNetworkFeeView)

        [minReceivedView, routeView, sendRatioView, receiveRatioView, originNetworkFeeView].forEach {
            $0.snp.makeConstraints { make in
                make.width.equalTo(self).offset(viewOffset)
                make.height.equalTo(LayoutConstants.networkFeeViewHeight)
            }
        }

        [minReceivedView, routeView, sendRatioView, receiveRatioView, originNetworkFeeView].forEach { $0.isHidden = true }
    }

    private func applyLocalization() {
        amountView.locale = locale
        receiveView.locale = locale
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        navigationTitleLabel.text = R.string.localizable.xcmTitle(preferredLanguages: locale.rLanguages)
        originNetworkFeeView.titleLabel.text = R.string.localizable.xcmOriginNetworkFeeTitle(preferredLanguages: locale.rLanguages)
        minReceivedView.titleLabel.text = R.string.localizable.polkaswapMinReceived(preferredLanguages: locale.rLanguages)
        routeView.titleLabel.text = R.string.localizable.polkaswapConfirmationRouteStub(preferredLanguages: locale.rLanguages)
    }

    private static func createMultiView() -> TitleMultiValueView {
        let view = UIFactory.default.createMultiView()
        view.titleLabel.font = .h6Title
        view.valueTop.font = .h5Title
        return view
    }
}
