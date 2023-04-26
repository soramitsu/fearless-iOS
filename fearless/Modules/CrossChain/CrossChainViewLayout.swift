import UIKit
import SnapKit

final class CrossChainViewLayout: UIView {
    enum LayoutConstants {
        static let verticalOffset: CGFloat = 25
        static let stackSubviewHeight: CGFloat = 64
        static let networkFeeViewHeight: CGFloat = 50

//        static let stackActionHeight: CGFloat = 32
//        static let stackViewSpacing: CGFloat = 12
//        static let bottomContainerHeight: CGFloat = 120
//        static let optionsImageSize: CGFloat = 16
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
        view.stackView.layoutMargins = UIEdgeInsets(
            top: 24.0,
            left: 0.0,
            bottom: 0.0,
            right: 0.0
        )
        view.stackView.spacing = LayoutConstants.verticalOffset
        return view
    }()

    let amountView = SelectableAmountInputView(type: .send)
    let originalSelectNetworkView = UIFactory.default.createNetworkView(selectable: true)
    let destSelectNetworkView = UIFactory.default.createNetworkView(selectable: true)

    let originNetworkFeeView = UIFactory.default.createMultiView()
    let destinationNetworkFeeView = UIFactory.default.createMultiView()

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
        backgroundColor = R.color.colorBlack02()
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
        originalSelectNetworkView.subtitle = originalSelectNetworkViewModel.chainName
        originalSelectNetworkViewModel.iconViewModel?.cancel(on: originalSelectNetworkView.iconView)
        originalSelectNetworkView.iconView.image = nil
        originalSelectNetworkViewModel
            .iconViewModel?
            .loadAmountInputIcon(on: originalSelectNetworkView.iconView, animated: true)
    }

    func bind(destSelectNetworkViewModel: SelectNetworkViewModel) {
        destSelectNetworkView.subtitle = destSelectNetworkViewModel.chainName
        destSelectNetworkViewModel.iconViewModel?.cancel(on: destSelectNetworkView.iconView)
        destSelectNetworkView.iconView.image = nil
        destSelectNetworkViewModel
            .iconViewModel?
            .loadAmountInputIcon(on: destSelectNetworkView.iconView, animated: true)
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
            make.height.equalTo(UIConstants.amountViewV2Height)
        }

        contentView.stackView.addArrangedSubview(originalSelectNetworkView)
        originalSelectNetworkView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
        }

        contentView.stackView.addArrangedSubview(destSelectNetworkView)
        destSelectNetworkView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
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
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        navigationTitleLabel.text = R.string.localizable.xcmTitle(preferredLanguages: locale.rLanguages)
        originalSelectNetworkView.title = R.string.localizable.xcmOriginalNetworkTitle(preferredLanguages: locale.rLanguages)
        destSelectNetworkView.title = R.string.localizable.xcmDestinationNetworkTitle(preferredLanguages: locale.rLanguages)
        originNetworkFeeView.titleLabel.text = R.string.localizable.xcmOriginNetworkFeeTitle(preferredLanguages: locale.rLanguages)
        destinationNetworkFeeView.titleLabel.text = R.string.localizable.xcmDestinationNetworkFeeTitle(preferredLanguages: locale.rLanguages)
    }
}
