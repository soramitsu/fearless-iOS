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
        /// Space between the header and the asset list below it.
        static let listSpacing: CGFloat = 8
        static let heroPadding: CGFloat = 20
        static let dialInset: CGFloat = 24
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

    /// On iPhone and in the iPad column the page: the header, then the asset list, scrolling as one. Side by side the
    /// header alone, beside the list.
    let headerScrollView = WalletHomePageScrollView()
    private var headerHeightLimit: Constraint?
    /// Side by side the header's content ends the scroll content; on the page the list does.
    private var contentBottom: Constraint?
    /// On the page: the list sits under the whole header and is as tall as the page, so scrolling the header away
    /// gives the list the page.
    private var listBelowHeader: Constraint?
    private var listFillsPage: Constraint?
    /// One list: while the list's search field has the keyboard, the list sits under the header's top rows and the
    /// page does not scroll.
    private var listBelowNavigation: Constraint?
    private var pageFitsWhileFolded: Constraint?
    private var listOffsetObservation: NSKeyValueObservation?
    /// The list the shown page scrolls; side by side it does not chain with the header.
    private weak var shownList: UIScrollView?
    private var pageOffsetObservation: NSKeyValueObservation?
    private var isChainingScroll = false
    private(set) var isSearchFocused = false
    private var appliedSearchFold = false
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
        updateNestedListScrolling()
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
        // Side by side, the header scrolls within the window's height; on the page it scrolls with the list.
        if placement == .split {
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
        headerScrollView.delegate = self
        addSubview(headerScrollView)
        headerScrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(headerScrollView.contentLayoutGuide)
            make.width.equalTo(headerScrollView.frameLayoutGuide)
            contentBottom = make.bottom.equalTo(headerScrollView.contentLayoutGuide).constraint
        }
        pageOffsetObservation = headerScrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            self?.chainScrolling(listMoved: false)
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

        installSkyCard()
        sunlit.heroSurface.addSubview(walletBalanceVStackView)
        walletBalanceVStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.bottom.equalToSuperview().inset(16)
            make.leading.trailing.equalToSuperview().inset(Constants.heroPadding)
        }
        // Kit v4: the sync dial is the card's instrument, inside its top-right registration bracket. It takes no
        // height from the header, which would push the round actions' labels under the list.
        sunlit.heroSurface.addSubview(sunlit.syncDial)
        sunlit.syncDial.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.dialInset)
            make.trailing.equalToSuperview().inset(Constants.dialInset)
            make.leading.greaterThanOrEqualTo(sunlit.sunBadge.snp.trailing).offset(8)
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
        headerScrollView.addSubview(pageViewControllerContainer)
        pageViewControllerContainer.addSubview(pageViewController.view)
        pageViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        placeHeaderAndList()
        applySearchFold()
    }
}

// MARK: - One-list search

extension WalletMainContainerViewLayout {
    /// While the list's search field has the keyboard, the balance card, the round actions and the segment fold
    /// away under the top rows so the matches have the page; they come back when the keyboard goes. Side by side
    /// nothing folds. Under Reduce Motion or Reduced effects the fold happens without movement.
    func setSearchFocused(_ focused: Bool, animated: Bool) {
        guard focused != isSearchFocused else { return }
        isSearchFocused = focused
        let wasFolded = appliedSearchFold
        applySearchFold()
        let folded = appliedSearchFold
        guard folded != wasFolded else { return }
        // The views fade with the fold: start from where they were.
        for view in foldingViews {
            view.alpha = wasFolded ? 0 : 1
        }
        let changes = {
            for view in self.foldingViews {
                view.alpha = folded ? 0 : 1
            }
            self.layoutIfNeeded()
        }
        let style = FWMotionPolicy.current().style(for: .tabChange)
        guard animated, window != nil, case let .full(duration) = style else {
            changes()
            return
        }
        UIView.animate(
            withDuration: duration, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: changes
        )
    }

    var isSearchFolded: Bool {
        isSearchFocused && placement != .split
    }

    /// The page (or, side by side, the header) is under a finger or still moving.
    var isScrollingPage: Bool {
        let pan = headerScrollView.panGestureRecognizer.state
        return headerScrollView.isDragging || headerScrollView.isDecelerating || pan == .began || pan == .changed
    }

    private var foldingViews: [UIView] {
        [sunlit.heroSurface, sunlit.actionsStack, segmentContainer]
    }

    private func applySearchFold() {
        let folded = isSearchFolded
        if folded {
            listBelowHeader?.deactivate()
            listFillsPage?.deactivate()
            listBelowNavigation?.activate()
            pageFitsWhileFolded?.activate()
            headerScrollView.setContentOffset(.zero, animated: false)
        } else {
            listBelowNavigation?.deactivate()
            pageFitsWhileFolded?.deactivate()
            listBelowHeader?.activate()
            listFillsPage?.activate()
        }
        headerScrollView.isScrollEnabled = !folded
        // Only a change of fold touches the folding views, so a launch flight's opacity is never overridden.
        if appliedSearchFold != folded {
            appliedSearchFold = folded
            for view in foldingViews {
                view.accessibilityElementsHidden = folded
                view.alpha = folded ? 0 : 1
            }
        }
        setNeedsLayout()
    }
}

// MARK: - Launch flight tiers (kit v4)

extension WalletMainContainerViewLayout {
    /// 0 the balance card, 1 the round actions, 2 the header, 4 the list (the tab bar and the list's segment control
    /// are declared by their own controllers).
    var flightTiers: [FWFlightTier] {
        [
            FWFlightTier(view: sunlit.heroSurface, tier: 0),
            FWFlightTier(view: sunlit.actionsStack, tier: 1),
            FWFlightTier(view: navigationContainerView, tier: 2),
            FWFlightTier(view: pageViewControllerContainer, tier: 4)
        ]
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
        applySearchFold()
    }

    func placeHeaderAndList() {
        switch placement {
        case .compact:
            headerScrollView.snp.remakeConstraints { make in
                make.top.equalTo(AdaptiveLayout.contentLayoutGuide(in: self).snp.top).offset(5)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(safeAreaLayoutGuide)
            }
            placeListInPage()
        case .column:
            headerScrollView.snp.remakeConstraints { make in
                make.top.equalTo(AdaptiveLayout.contentLayoutGuide(in: self).snp.top).offset(5)
                make.centerX.equalTo(safeAreaLayoutGuide)
                make.width.equalTo(safeAreaLayoutGuide).priority(.high)
                make.width.lessThanOrEqualTo(AdaptiveLayout.contentColumnWidth)
                make.bottom.equalTo(safeAreaLayoutGuide)
            }
            placeListInPage()
        case .split:
            headerScrollView.snp.remakeConstraints { make in
                make.top.equalTo(AdaptiveLayout.contentLayoutGuide(in: self).snp.top).offset(5)
                make.leading.equalTo(safeAreaLayoutGuide).offset(Constants.splitSpacing)
                make.width.equalTo(Constants.splitHeaderWidth)
                make.height.equalTo(contentView.snp.height).priority(.high)
                headerHeightLimit = make.height.lessThanOrEqualTo(safeAreaLayoutGuide.snp.height)
                    .offset(-5).constraint
            }
            headerScrollView.contentLayoutGuide.snp.removeConstraints()
            headerScrollView.bounces = true
            contentBottom?.activate()
            // Side by side, the list has the window's height already; nothing folds.
            listBelowHeader = nil
            listFillsPage = nil
            listBelowNavigation = nil
            pageFitsWhileFolded = nil
            addSubview(pageViewControllerContainer)
            pageViewControllerContainer.snp.remakeConstraints { make in
                make.top.equalTo(AdaptiveLayout.contentLayoutGuide(in: self).snp.top).offset(5)
                make.leading.equalTo(headerScrollView.snp.trailing).offset(Constants.splitSpacing)
                make.trailing.equalTo(safeAreaLayoutGuide).offset(-Constants.splitSpacing)
                make.bottom.equalTo(safeAreaLayoutGuide)
            }
        }
    }

    /// The list goes under the header inside the page and is as tall as the page: the page scrolls the header away,
    /// then the list scrolls its rows. Nothing caps the header, so none of it rests under the list at any text size.
    func placeListInPage() {
        headerHeightLimit = nil
        contentBottom?.deactivate()
        let page = headerScrollView
        // A drag on the list moves the page too: a page that bounced would move the list's rows twice as far, and
        // at the top it would take the pull that refreshes the list.
        page.bounces = false
        page.addSubview(pageViewControllerContainer)
        pageViewControllerContainer.snp.remakeConstraints { make in
            listBelowHeader = make.top.equalTo(contentView.snp.bottom).offset(Constants.listSpacing).constraint
            listBelowNavigation = make.top.equalTo(navigationContainerView.snp.bottom)
                .offset(Constants.listSpacing).constraint
            make.leading.trailing.equalTo(page.frameLayoutGuide)
            make.bottom.equalTo(page.contentLayoutGuide)
            listFillsPage = make.height.equalTo(page.frameLayoutGuide).constraint
        }
        page.contentLayoutGuide.snp.remakeConstraints { make in
            pageFitsWhileFolded = make.height.equalTo(page.frameLayoutGuide).constraint
        }
        listBelowNavigation?.deactivate()
        pageFitsWhileFolded?.deactivate()
    }
}

// MARK: - One page: the header and the list

private extension WalletMainContainerViewLayout {
    /// Follows the list the page shows (another page, such as NFTs, has its own) and keeps the page's offset within
    /// its content after a layout change.
    func updateNestedListScrolling() {
        let shown = Self.verticalScrollView(in: pageViewController.viewControllers?.first?.view)
        shownList = shown
        let nested = placement == .split ? nil : shown
        if nested !== headerScrollView.nestedScrollView {
            headerScrollView.nestedScrollView = nested
            listOffsetObservation = nested?.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                self?.chainScrolling(listMoved: true)
            }
        }
        let pageMax = max(0, headerScrollView.contentSize.height - headerScrollView.bounds.height)
        if headerScrollView.contentOffset.y > pageMax {
            headerScrollView.contentOffset.y = pageMax
        }
        assignScrollToTop()
    }

    /// The list a page shows: its frontmost vertically scrolling view, so an empty state that covers the list
    /// (a ScrollableContainerView) is followed rather than the list under it. The list is found before the network
    /// chips and banner carousels inside it.
    static func verticalScrollView(in root: UIView?) -> UIScrollView? {
        guard let root, !root.isHidden, root.alpha > 0.01 else { return nil }
        if let scroll = root as? UIScrollView, scroll.isScrollEnabled, !scroll.isPagingEnabled, !(scroll is UITextView),
           scroll.alwaysBounceVertical || scroll is UITableView || scroll is UICollectionView
           || scroll.superview is ScrollableContainerView {
            return scroll
        }
        return root.subviews.reversed().lazy.compactMap { verticalScrollView(in: $0) }.first
    }

    func chainOffsets(list: UIScrollView) -> WalletHomeScrollChain.Offsets {
        WalletHomeScrollChain.Offsets(
            page: headerScrollView.contentOffset.y,
            list: list.contentOffset.y + list.adjustedContentInset.top
        )
    }

    /// One drag moves the page and the list together; this holds the one that must wait (see `WalletHomeScrollChain`).
    func chainScrolling(listMoved: Bool) {
        guard !isChainingScroll, placement != .split, let list = headerScrollView.nestedScrollView else { return }
        defer { updateScrollToTopTarget() }
        let page = headerScrollView
        let listTop = -list.adjustedContentInset.top
        let move: WalletHomeScrollChain.Move
        if listMoved {
            move = list.isTracking || list.isDecelerating ? .list : .listProgrammatically
        } else {
            move = .page
        }
        let current = chainOffsets(list: list)
        let resolved = WalletHomeScrollChain.resolve(
            current,
            pageMax: max(0, page.contentSize.height - page.bounds.height),
            moved: move
        )
        guard resolved != current else { return }
        isChainingScroll = true
        if resolved.page != current.page {
            page.contentOffset.y = resolved.page
        }
        if resolved.list != current.list {
            list.contentOffset.y = resolved.list + listTop
        }
        isChainingScroll = false
    }
}

// MARK: - The status-bar tap

extension WalletMainContainerViewLayout: UIScrollViewDelegate {
    /// The page's request brings the list it carries to its top as well, so the whole home returns to its top. The list
    /// goes first and at once: while its rows are scrolled the drag chain holds the page with the header away.
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        // A list replaced since the last layout pass (an empty state, another appearance) is the one to reset.
        layoutIfNeeded()
        if scrollView === headerScrollView, let list = headerScrollView.nestedScrollView {
            // A table measuring rows it had only estimated (after a width change) shifts itself off its top once.
            for _ in 0 ..< 3 where list.contentOffset.y != -list.adjustedContentInset.top {
                let top = CGPoint(x: list.contentOffset.x, y: -list.adjustedContentInset.top)
                list.setContentOffset(top, animated: false)
                list.layoutIfNeeded()
            }
        }
        return true
    }
}

extension WalletMainContainerViewLayout {
    /// Gives the status-bar tap to `scrollToTopTargets` alone among `root` and every view inside it, by default the
    /// whole home: the pager, the lists, their chip rows, carousels and empty states, shown or hidden. A page about to
    /// slide in is passed before it joins the home.
    func assignScrollToTop(in root: UIView? = nil) {
        let targets = scrollToTopTargets
        var pending: [UIView] = [root ?? self]
        while let view = pending.popLast() {
            if let scroll = view as? UIScrollView {
                let eligible = targets.contains { $0 === scroll }
                if scroll.scrollsToTop != eligible {
                    scroll.scrollsToTop = eligible
                }
            }
            pending.append(contentsOf: view.subviews)
        }
    }
}

private extension WalletMainContainerViewLayout {
    /// UIKit offers the status-bar tap to a scroll view under the tap's x that can still move up and picks the
    /// innermost one, so one view per column of the home is eligible. On the page: the page, or its list while the page
    /// rests at its top above scrolled rows (see `WalletHomeScrollChain.scrollToTopTarget`). Side by side the header and
    /// the list are separate columns that never share an x, so each takes the taps above it.
    var scrollToTopTargets: [UIScrollView] {
        guard let list = shownList else { return [headerScrollView] }
        guard placement != .split else { return [headerScrollView, list] }
        switch WalletHomeScrollChain.scrollToTopTarget(chainOffsets(list: list)) {
        case .page: return [headerScrollView]
        case .list: return [list]
        }
    }

    /// While the page carries a list only these two can take the tap; a scroll moves it between them.
    func updateScrollToTopTarget() {
        let targets = scrollToTopTargets
        for scroll in [headerScrollView, shownList].compactMap({ $0 }) {
            let eligible = targets.contains { $0 === scroll }
            if scroll.scrollsToTop != eligible {
                scroll.scrollsToTop = eligible
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
