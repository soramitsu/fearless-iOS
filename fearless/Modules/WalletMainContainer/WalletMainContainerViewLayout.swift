import UIKit
import SnapKit

final class WalletMainContainerViewLayout: UIView {
    private enum Constants {
        static let walletIconSize: CGFloat = 44.0
        static let accessoryButtonSize: CGFloat = 44.0
        /// Narrowest regular-width window that shows the wallet beside its asset list.
        static let splitMinimumWidth: CGFloat = 860
        static let splitHeaderWidth: CGFloat = 360
        static let splitSpacing: CGFloat = 24
        static let sunSize: CGFloat = 88
        /// Height the asset list keeps below the header; the header scrolls inside the rest.
        static let assetViewportMinimum: CGFloat = 220
        static let heroPadding: CGFloat = 20
    }

    /// Where the wallet header and the asset list go: stacked at full width (iPhone
    /// and compact iPad windows), stacked in a centered column, or side by side.
    private enum Placement: Equatable {
        case compact
        case column
        case split
    }

    private var placement: Placement = .compact

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    /// The sun-lit page, hero card, sun and round actions (see WalletMainContainerViewLayout+Sunlit).
    let sunlit = WalletHomeSunlitParts()

    let contentView: UIStackView = {
        let view = UIFactory.default.createVerticalStackView()
        view.alignment = .center
        return view
    }()

    let headerScrollView = UIScrollView()
    private var headerHeightLimit: Constraint?
    private var accessibleNetworkWidth: Constraint?

    // MARK: - Navigation view properties

    private let navigationContainerView = UIView()

    let switchWalletButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconFearlessRounded(), for: .normal)
        return button
    }()

    let accountScoreView = AccountScoreView()

    private let walletNameTitle: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textAlignment = .left
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2
        return label
    }()

    let selectNetworkButton = SelectedNetworkButton()

    let scanQRButton = FWRoundIconButton.make(image: R.image.iconScanQr())
    let searchButton = FWRoundIconButton.make(image: R.image.iconSearchWhite())

    private let walletBalanceVStackView = UIFactory.default.createVerticalStackView(spacing: 4)
    let walletBalanceViewContainer = UIView()

    // MARK: - Address label

    let addressCopyableLabel = CopyableLabelView()

    // MARK: - FWSegmentedControl

    let segmentContainer = UIView()
    let segmentedControl = FWSegmentedControl()

    // MARK: - UIPageViewController

    let pageViewControllerContainer = UIView()

    let pageViewController: UIPageViewController = .init(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        updateHeaderScrolling()
        updateTopRowAxis()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateHeaderScrolling()
        updateTopRowAxis()
        updateTypography()
    }

    override func layoutSubviews() {
        updatePlacement()
        super.layoutSubviews()
        updateSunPosition()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        // The sidebar can appear or hide without changing this view's bounds.
        setNeedsLayout()
    }

    private func updateHeaderScrolling() {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            accessibleNetworkWidth?.activate()
        } else {
            accessibleNetworkWidth?.deactivate()
        }
        // Side by side, the header always scrolls within the window's height.
        if placement == .split || FWAppearance.walletHeaderRestyled ||
            traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            headerHeightLimit?.activate()
        } else {
            headerHeightLimit?.deactivate()
        }
    }

    // MARK: - Public methods

    func bind(viewModel: WalletMainContainerViewModel) {
        walletNameTitle.text = viewModel.walletName
        selectNetworkButton.set(text: viewModel.selectedFilter, image: viewModel.selectedFilterImage)
        selectNetworkButton.accessibilityValue = viewModel.selectedFilter
        switchWalletButton.accessibilityValue = viewModel.walletName
        if let address = viewModel.address {
            addressCopyableLabel.isHidden = false
            addressCopyableLabel.bind(title: address)
        } else {
            addressCopyableLabel.isHidden = true
        }

        accountScoreView.bind(viewModel: viewModel.accountScoreViewModel)
    }

    func addBalance(_ view: UIView) {
        if let balance = view as? BalanceInfoViewLayout {
            balance.configurePortfolioPresentation(locale: locale)
            balance.onLoadingChange = { [weak self] loading in
                self?.setBalanceLoading(loading)
            }
            setBalanceLoading(balance.isLoadingTotal)
        }
        walletBalanceViewContainer.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bind(accountScoreViewModel: AccountScoreViewModel) {
        accountScoreView.bind(viewModel: accountScoreViewModel)
    }

    // MARK: - Private methods

    private func applyLocalization() {
        let localizedItems = [
            R.string.localizable.сurrenciesStubText(preferredLanguages: locale.rLanguages),
            R.string.localizable.nftsStub(preferredLanguages: locale.rLanguages)
        ]
        segmentedControl.setSegmentItems(localizedItems)
        localizeActions()
        guard FWAppearance.walletHeaderRestyled else { return }
        switchWalletButton.accessibilityLabel = PortfolioHeaderText.string("ux.switch_wallet", locale: locale)
        selectNetworkButton.accessibilityLabel = PortfolioHeaderText.string("ux.choose_network", locale: locale)
        searchButton.accessibilityLabel = PortfolioHeaderText.string("ux.search_assets", locale: locale)
        scanQRButton.accessibilityLabel = PortfolioHeaderText.string("ux.scan_qr", locale: locale)
        addressCopyableLabel.accessibilityLabel = R.string.localizable
            .commonCopyAddress(preferredLanguages: locale.rLanguages)
        walletBalanceViewContainer.subviews.compactMap { $0 as? BalanceInfoViewLayout }.forEach {
            $0.configurePortfolioPresentation(locale: locale)
        }
        updateTypography()
    }

    private func updateTypography() {
        guard FWAppearance.walletHeaderRestyled else { return }
        walletNameTitle.numberOfLines = 0
        walletNameTitle.lineBreakMode = .byCharWrapping
        walletNameTitle.setContentCompressionResistancePriority(.required, for: .vertical)
        walletNameTitle.font = .fw(.titleS, locale: locale, compatibleWith: traitCollection)
        selectNetworkButton.applyTypography(.fw(.bodyM, locale: locale, compatibleWith: traitCollection))
        addressCopyableLabel.applyTypography(.fw(.bodyS, locale: locale, compatibleWith: traitCollection))
    }

    // MARK: - Private layout methods

    private func setupLayout() {
        installSunlitPage()

        headerScrollView.contentInsetAdjustmentBehavior = .never
        addSubview(headerScrollView)
        headerScrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(headerScrollView.contentLayoutGuide)
            make.width.equalTo(headerScrollView.frameLayoutGuide)
        }

        setupNavigationViewLayout()
        setupWalletBalanceLayout()
        setupActionsLayout()
        setupSegmentedLayout()
        setupListLayout()

        segmentContainer.isHidden = true
    }

    private func setupNavigationViewLayout() {
        let identityRow = UIStackView(arrangedSubviews: [switchWalletButton, walletNameTitle])
        identityRow.axis = .horizontal
        identityRow.alignment = .center
        identityRow.spacing = 12
        arrangeTopRow(identity: identityRow, title: walletNameTitle)
        switchWalletButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.walletIconSize)
        }
        selectNetworkButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Constants.accessoryButtonSize)
            make.width.greaterThanOrEqualTo(Constants.accessoryButtonSize)
        }
        for button in [searchButton, scanQRButton] {
            button.snp.makeConstraints { make in make.size.equalTo(Constants.accessoryButtonSize) }
        }
        let networkRow = UIStackView(arrangedSubviews: [selectNetworkButton, UIView()])
        networkRow.axis = .horizontal
        networkRow.alignment = .center
        let headerStack = UIStackView(arrangedSubviews: [sunlit.topRow, networkRow])
        headerStack.axis = .vertical
        headerStack.spacing = 12
        navigationContainerView.addSubview(headerStack)
        headerStack.snp.makeConstraints { make in make.edges.equalToSuperview() }
        selectNetworkButton.snp.makeConstraints { make in
            accessibleNetworkWidth = make.width.equalTo(navigationContainerView).constraint
        }
        accessibleNetworkWidth?.deactivate()
        contentView.addArrangedSubview(navigationContainerView)
        navigationContainerView.snp.makeConstraints { make in
            make.width.equalTo(contentView.snp.width).offset(-2.0 * UIConstants.horizontalInset)
        }
        switchWalletButton.accessibilityLabel = NSLocalizedString(
            "ux.switch_wallet",
            value: "Switch wallet",
            comment: ""
        )
        selectNetworkButton.accessibilityLabel = NSLocalizedString(
            "ux.choose_network",
            value: "Choose network",
            comment: ""
        )
        searchButton.accessibilityLabel = NSLocalizedString("ux.search_assets", value: "Search assets", comment: "")
        scanQRButton.accessibilityLabel = NSLocalizedString("ux.scan_qr", value: "Scan QR code", comment: "")
    }

    private func setupWalletBalanceLayout() {
        // Account score is secondary context, below the balance rather than beside navigation.
        addressCopyableLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(200)
            make.height.greaterThanOrEqualTo(44)
        }

        walletBalanceViewContainer.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(58)
        }

        walletBalanceVStackView.distribution = .fill
        walletBalanceVStackView.alignment = .center
        walletBalanceVStackView.addArrangedSubview(sunlit.sunBadge)
        walletBalanceVStackView.addArrangedSubview(walletBalanceViewContainer)
        walletBalanceVStackView.addArrangedSubview(addressCopyableLabel)
        walletBalanceVStackView.addArrangedSubview(accountScoreView)
        walletBalanceVStackView.setCustomSpacing(6, after: sunlit.sunBadge)
        walletBalanceVStackView.setCustomSpacing(10, after: walletBalanceViewContainer)
        walletBalanceVStackView.setCustomSpacing(4, after: addressCopyableLabel)
        sunlit.sunBadge.snp.makeConstraints { make in
            make.size.equalTo(Constants.sunSize)
        }

        sunlit.heroSurface.addSubview(walletBalanceVStackView)
        walletBalanceVStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.bottom.equalToSuperview().inset(16)
            make.leading.trailing.equalToSuperview().inset(Constants.heroPadding)
        }
        contentView.setCustomSpacing(16, after: navigationContainerView)
        contentView.addArrangedSubview(sunlit.heroSurface)
        sunlit.heroSurface.snp.makeConstraints { make in
            make.width.equalTo(contentView.snp.width).offset(-2.0 * FWSunlit.Spacing.gutter)
        }
        walletBalanceViewContainer.snp.makeConstraints { make in
            make.width.equalTo(walletBalanceVStackView)
        }
    }

    private func setupSegmentedLayout() {
        contentView.setCustomSpacing(20, after: sunlit.actionsStack)
        contentView.addArrangedSubview(segmentContainer)
        segmentContainer.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.width.equalTo(contentView.snp.width).offset(-2.0 * UIConstants.horizontalInset)
            make.edges.equalToSuperview()
        }
    }

    private func setupListLayout() {
        addSubview(pageViewControllerContainer)
        pageViewControllerContainer.addSubview(pageViewController.view)
        pageViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        placeHeaderAndList()
    }
}

// MARK: - Adaptive placement

private extension WalletMainContainerViewLayout {
    func updatePlacement() {
        let newPlacement: Placement
        if AdaptiveLayout.isRegularWidth(traitCollection) {
            // The native tab sidebar narrows the safe area beside the wallet.
            let usableWidth = bounds.inset(by: safeAreaInsets).width
            newPlacement = usableWidth >= Constants.splitMinimumWidth ? .split : .column
        } else {
            newPlacement = .compact
        }
        guard newPlacement != placement else {
            return
        }

        placement = newPlacement
        placeHeaderAndList()
        updateHeaderScrolling()
    }

    func placeHeaderAndList() {
        switch placement {
        case .compact:
            headerScrollView.snp.remakeConstraints { make in
                make.top.equalTo(AdaptiveLayout.contentLayoutGuide(in: self).snp.top).offset(5)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(contentView.snp.height).priority(.high)
                headerHeightLimit = make.height.lessThanOrEqualTo(safeAreaLayoutGuide.snp.height)
                    .offset(-Constants.assetViewportMinimum).constraint
            }
            pageViewControllerContainer.snp.remakeConstraints { make in
                make.top.equalTo(headerScrollView.snp.bottom).offset(8)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(safeAreaLayoutGuide)
            }
        case .column:
            headerScrollView.snp.remakeConstraints { make in
                make.top.equalTo(AdaptiveLayout.contentLayoutGuide(in: self).snp.top).offset(5)
                make.centerX.equalTo(safeAreaLayoutGuide)
                make.width.equalTo(safeAreaLayoutGuide).priority(.high)
                make.width.lessThanOrEqualTo(AdaptiveLayout.contentColumnWidth)
                make.height.equalTo(contentView.snp.height).priority(.high)
                headerHeightLimit = make.height.lessThanOrEqualTo(safeAreaLayoutGuide.snp.height)
                    .offset(-Constants.assetViewportMinimum).constraint
            }
            pageViewControllerContainer.snp.remakeConstraints { make in
                make.top.equalTo(headerScrollView.snp.bottom).offset(8)
                make.leading.trailing.equalTo(headerScrollView)
                make.bottom.equalTo(safeAreaLayoutGuide)
            }
        case .split:
            headerScrollView.snp.remakeConstraints { make in
                make.top.equalTo(AdaptiveLayout.contentLayoutGuide(in: self).snp.top).offset(5)
                make.leading.equalTo(safeAreaLayoutGuide).offset(Constants.splitSpacing)
                make.width.equalTo(Constants.splitHeaderWidth)
                make.height.equalTo(contentView.snp.height).priority(.high)
                headerHeightLimit = make.height.lessThanOrEqualTo(safeAreaLayoutGuide.snp.height)
                    .offset(-5).constraint
            }
            pageViewControllerContainer.snp.remakeConstraints { make in
                make.top.equalTo(AdaptiveLayout.contentLayoutGuide(in: self).snp.top).offset(5)
                make.leading.equalTo(headerScrollView.snp.trailing).offset(Constants.splitSpacing)
                make.trailing.equalTo(safeAreaLayoutGuide).offset(-Constants.splitSpacing)
                make.bottom.equalTo(safeAreaLayoutGuide)
            }
        }
    }
}

/// Resource lookup follows the selected app locale, including its region fallback.
enum PortfolioHeaderText {
    static func string(_ key: String, locale: Locale) -> String {
        let path = Bundle.main.path(forResource: locale.identifier, ofType: "lproj")
            ?? locale.languageCode.flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
            ?? Bundle.main.path(forResource: "en", ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }
}
