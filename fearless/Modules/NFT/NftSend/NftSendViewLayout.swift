import UIKit
import SnapKit

final class NftSendViewLayout: UIView {
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

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 2
        return label
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = LayoutConstants.contentViewLayoutMargins
        view.stackView.spacing = LayoutConstants.verticalOffset
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

    let myWalletsButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyStackButtonStyle()
        button.imageWithTitleView?.iconImage = R.image.fearlessRoundedIconSmall()
        return button
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    let searchView = SearchTriangularedView(withPasteButton: true)

    let feeView: NetworkFeeView = {
        let view = UIFactory.default.createNetworkFeeView()
        view.borderView.isHidden = true
        return view
    }()

    let scamWarningView: ScamWarningExpandableView = {
        let view = ScamWarningExpandableView()
        view.isHidden = true
        return view
    }()

    let mediaView: UniversalMediaView = {
        let mediaView = UniversalMediaView(frame: .zero)
        mediaView.allowLooping = true
        mediaView.shouldHidePlayButton = true
        mediaView.shouldAutoPlayAfterPresentation = true
        mediaView.backgroundColor = .clear
        return mediaView
    }()

    var locale = Locale.current {
        didSet {
            searchView.locale = locale
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

    func setupLayout() {
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

        contentView.stackView.addArrangedSubview(feeView)
        feeView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.networkFeeViewHeight)
        }

        contentView.stackView.addArrangedSubview(scamWarningView)
        scamWarningView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
        }
    }

    func applyLocalization() {
        feeView.locale = locale
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
            .commonContinue(preferredLanguages: locale.rLanguages)

        scanButton.imageWithTitleView?.title = R.string.localizable.scanQrTitle(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        historyButton.imageWithTitleView?.title = R.string.localizable.walletSearchContacts(
            preferredLanguages: locale.rLanguages
        ).uppercased()

        myWalletsButton.imageWithTitleView?.title = R.string.localizable.xcmMywalletsButtonTitle(
            preferredLanguages: locale.rLanguages
        )

        navigationTitleLabel.text = R.string.localizable
            .chooseRecipientTitle(preferredLanguages: locale.rLanguages)
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.bind(viewModel: feeViewModel)
    }

    func bind(scamInfo: ScamInfo?) {
        guard let scamInfo = scamInfo else {
            scamWarningView.isHidden = true
            return
        }
        scamWarningView.isHidden = false

        scamWarningView.bind(scamInfo: scamInfo, assetName: "")
    }

    func bind(viewModel: RecipientViewModel) {
        searchView.textField.text = viewModel.address
        searchView.updateState(icon: viewModel.icon)
    }
}
