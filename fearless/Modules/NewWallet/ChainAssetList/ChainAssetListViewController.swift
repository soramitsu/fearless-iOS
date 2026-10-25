import UIKit
import SoraFoundation
import SnapKit
import SoraUI
import SSFModels

final class ChainAssetListViewController:
    UIViewController,
    ViewHolder,
    KeyboardViewAdoptable {
    typealias RootViewType = ChainAssetListViewLayout

    var keyboardHandler: FearlessKeyboardHandler?

    // MARK: Private properties

    private let output: ChainAssetListViewOutput

    private weak var bannersViewController: UIViewController?
    private let keyboardAdoptable: Bool

    private var viewModel: ChainAssetListViewModel?
    private var collapsedNetworkSectionIds: Set<String> = []
    private let collapseStore: PortfolioCollapseStore
    private var presentationWalletId: String?
    private var presentationRevision = UUID()
    private var expandedTokenIds: Set<String> = []
    private var expandedZeroTokenIds: Set<String> = []
    private var zeroTokensExpanded = false
    private var usesTokenLens: Bool { viewModel?.lens == .token }
    private var tokenSectionCount: Int { usesTokenLens ? (viewModel?.zeroTokenRows.isEmpty == false ? 2 : 1) : 0 }
    private func tokenRows(in section: Int) -> [TokenPortfolioRow] {
        guard let viewModel, usesTokenLens, section < tokenSectionCount else { return [] }
        if section == 1, !zeroTokensExpanded { return [] }
        return TokenPortfolioProjection.rows(
            section == 0 ? viewModel.tokenRows : viewModel.zeroTokenRows,
            expanded: expandedTokenIds,
            expandedZero: expandedZeroTokenIds
        )
    }

    private func tokenRow(at indexPath: IndexPath) -> TokenPortfolioRow? {
        tokenRows(in: indexPath.section)[safe: indexPath.row]
    }

    private var visibleNetworkSections: [AssetNetworkSectionViewModel] {
        viewModel?.networkSections.filter { section in
            if usesTokenLens { return section.kind == .detected }
            return section.parentSectionId.map { !collapsedNetworkSectionIds.contains($0) } ?? true
        } ?? []
    }

    private var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    // MARK: - Constructor

    init(
        bannersViewController: UIViewController?,
        output: ChainAssetListViewOutput,
        keyboardAdoptable: Bool,
        localizationManager: LocalizationManagerProtocol?,
        collapseStore: PortfolioCollapseStore = PortfolioCollapseStore()
    ) {
        self.bannersViewController = bannersViewController
        self.keyboardAdoptable = keyboardAdoptable
        self.output = output
        self.collapseStore = collapseStore
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = ChainAssetListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
        setupEmbededViews()
        bindActions()
        applyLocalization()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil, keyboardAdoptable {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clearKeyboardHandler()
    }

    // MARK: - KeyboardViewAdoptable

    var target: Constraint? { rootView.keyboardAdoptableConstraint }

    func offsetFromKeyboardWithInset(_: CGFloat) -> CGFloat { 0 }
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}

// MARK: - Private methods

private extension ChainAssetListViewController {
    func configureTableView() {
        rootView.tableView.registerClassForCell(ChainAccountBalanceTableCell.self)
        rootView.tableView.registerClassForCell(TokenGroupBalanceTableCell.self)
        rootView.tableView.register(
            AssetNetworkHeaderView.self,
            forHeaderFooterViewReuseIdentifier: AssetNetworkHeaderView.reuseId
        )
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.estimatedRowHeight = 93
        rootView.tableView.estimatedSectionHeaderHeight = 52

        if #available(iOS 15.0, *) {
            rootView.tableView.sectionHeaderTopPadding = 0
        }

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(
                self,
                action: #selector(handlePullToRefresh),
                for: .valueChanged
            )
        }
    }

    func cellViewModel(for indexPath: IndexPath) -> ChainAccountBalanceCellViewModel? {
        switch tokenRow(at: indexPath) {
        case let .asset(key): return viewModel?.tokenChildCells[key]
        case let .token(row) where row.model.isSingleNetwork:
            return row.model.children.first.flatMap { viewModel?.tokenChildCells[$0.chainAsset.assetKey] }
        case .token, .zeroChildren: return nil
        case nil: break
        }
        if let section = visibleNetworkSections[safe: indexPath.section - tokenSectionCount] {
            return section.rows[safe: indexPath.row]
        }
        if usesTokenLens { return nil }
        return viewModel?.displayState.rows[safe: indexPath.row]
    }

    func setupEmbededViews() {
        guard let bannersViewController = bannersViewController else {
            return
        }

        addChild(bannersViewController)

        rootView.addBanners(view: bannersViewController.view)
        bannersViewController.didMove(toParent: self)
    }

    func bindActions() {
        rootView.lensControl.addTarget(self, action: #selector(didChangeLens), for: .valueChanged)
        rootView.exclusionsView.onTapHiddenAssets = { [weak self] in
            self?.output.didTapHiddenAssetsNotIncluded()
        }
        rootView.exclusionsView.onTapTestnetAssets = { [weak self] in
            self?.output.didTapTestnetAssetsNotIncluded()
        }
        rootView.hiddenFundsNoticeView.onReview = { [weak self] in
            self?.output.didTapReviewHiddenFunds()
        }
        rootView.hiddenFundsNoticeView.onKeepHidden = { [weak self] in
            guard let notice = self?.viewModel?.hiddenFundsNotice else {
                return
            }
            self?.output.didTapKeepHiddenFunds(assetKeys: notice.assetKeys)
        }
        rootView.footerButton.addAction { [weak self] in
            guard let self, let viewModel = self.viewModel else {
                return
            }
            switch viewModel.displayState {
            case .defaultList, .allIsHidden:
                self.output.didTapManageAsset()
            case let .chainHasNetworkIssue(chain):
                self.rootView.footerButton.set(loading: true)
                self.output.didTapResolveNetworkIssue(for: chain)
            case let .chainHasAccountIssue(chain):
                self.output.didTapResolveAccountIssue(for: chain)
            case .search:
                break
            }
        }
    }

    @objc func handlePullToRefresh() {
        output.didPullToRefresh()
        rootView.tableView.refreshControl?.endRefreshing()
    }

    @objc func didChangeLens() {
        guard let walletId = presentationWalletId else { return }
        let lens: PortfolioLens = rootView.lensControl.selectedSegmentIndex == 0 ? .token : .network
        collapseStore.setLens(lens, walletId: walletId)
        output.didSelectLens(lens, walletId: walletId)
    }

    func activateTokenRow(at indexPath: IndexPath) {
        guard let row = tokenRow(at: indexPath), let walletId = presentationWalletId else { return }
        switch row {
        case let .token(group) where !group.model.isSingleNetwork:
            if expandedTokenIds.contains(group.model.id) { expandedTokenIds.remove(group.model.id) }
            else { expandedTokenIds.insert(group.model.id) }
            collapseStore.setIdentifiers(expandedTokenIds, walletId: walletId, kind: "token")
        case let .zeroChildren(groupId, _):
            if expandedZeroTokenIds.contains(groupId) { expandedZeroTokenIds.remove(groupId) }
            else { expandedZeroTokenIds.insert(groupId) }
            collapseStore.setIdentifiers(expandedZeroTokenIds, walletId: walletId, kind: "token-zero")
        default:
            if let cell = cellViewModel(for: indexPath) { output.didSelectViewModel(cell) }
            return
        }
        // Preserve identities atomically during asynchronous balance/wallet updates.
        // This also supplies the Reduce Motion path without row movement.
        rootView.tableView.reloadData()
    }

    func tokenAction(_ action: SwipableCellButtonType, row: TokenGroupRowViewModel, walletId: String) {
        output.didTapTokenAction(actionType: action, groupId: row.model.id, walletId: walletId)
    }
}

// MARK: - ChainAssetListViewInput

extension ChainAssetListViewController: ChainAssetListViewInput {
    func reloadBanners() {
        guard viewModel != nil else {
            return
        }
        rootView.setHeaderView()
    }

    func didReceive(viewModel: ChainAssetListViewModel) {
        presentationRevision = UUID()
        self.viewModel = viewModel
        if let walletId = viewModel.walletId {
            if presentationWalletId != walletId {
                presentationWalletId = walletId
                collapsedNetworkSectionIds = collapseStore.identifiers(walletId: walletId, kind: "network")
                expandedTokenIds = collapseStore.identifiers(walletId: walletId, kind: "token")
                expandedZeroTokenIds = collapseStore.identifiers(walletId: walletId, kind: "token-zero")
                zeroTokensExpanded = collapseStore.identifiers(walletId: walletId, kind: "summary-expanded")
                    .contains("zero-tokens")
            }
            let expanded = collapseStore.identifiers(walletId: walletId, kind: "summary-expanded")
            for section in viewModel.networkSections where section.kind != .assets {
                if expanded.contains(section.id) { collapsedNetworkSectionIds.remove(section.id) }
                else { collapsedNetworkSectionIds.insert(section.id) }
            }
        }
        rootView.lensControl.selectedSegmentIndex = viewModel.lens == .token ? 0 : 1
        rootView.customOrderLabel.isHidden = !viewModel.usesCustomOrder
        rootView.setFooterButtonTitle(for: viewModel.displayState)
        rootView.footerButton.isHidden = viewModel.displayState.isSearch
        rootView.bannersView?.isHidden = viewModel.displayState.isSearch
        rootView.footerButton.set(loading: false)
        rootView.exclusionsView.bind(captions: viewModel.exclusions)
        rootView.hiddenFundsNoticeView.bind(viewModel.hiddenFundsNotice)
        rootView.emptyWalletView.bind(
            visible: viewModel.showsFundingCard,
            canReceive: viewModel.canReceive,
            canBuy: viewModel.canBuy,
            locale: locale
        )
        let revision = presentationRevision
        let walletId = viewModel.walletId
        rootView.emptyWalletView.onReceive = { [weak self] in
            guard let self, self.presentationRevision == revision, let walletId,
                  self.presentationWalletId == walletId else { return }
            self.output.didTapFunding(.receive, walletId: walletId)
        }
        rootView.emptyWalletView.onBuy = { [weak self] in
            guard let self, self.presentationRevision == revision, let walletId,
                  self.presentationWalletId == walletId else { return }
            self.output.didTapFunding(.buy, walletId: walletId)
        }

        switch viewModel.displayState {
        case let .defaultList(_, withAnimate):
            rootView.setHeaderView()
            rootView.setFooterView()
            guard rootView.isAnimating == false else {
                return
            }

            rootView.tableView.reloadData()

            if withAnimate {
                rootView.runManageAssetAnimate(finish: { [weak self] in
                    self?.output.didFinishManageAssetAnimate()
                    self?.rootView.tableView.reloadData()
                })
            }
        case .chainHasNetworkIssue, .chainHasAccountIssue, .allIsHidden:
            rootView.setHeaderView()
            rootView.removeFooterView()
            rootView.tableView.reloadData()
        case .search:
            let isEmpty = viewModel.displayState.rows.isEmpty
            isEmpty ? rootView.removeFooterView() : rootView.setFooterView()
            rootView.setHeaderView()
            rootView.tableView.reloadData()
        }
        reloadEmptyState(animated: false)
    }
}

// MARK: - Localizable

extension ChainAssetListViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
        if let viewModel {
            rootView.emptyWalletView.bind(
                visible: viewModel.showsFundingCard,
                canReceive: viewModel.canReceive,
                canBuy: viewModel.canBuy,
                locale: locale
            )
            rootView.setHeaderView()
        }
    }
}

extension ChainAssetListViewController: SwipableTableViewCellDelegate {
    func swipeCellDidTap(on actionType: SwipableCellButtonType, with indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            return
        }
        if case let .token(row) = tokenRow(at: indexPath), let walletId = presentationWalletId {
            tokenAction(actionType, row: row, walletId: walletId)
            return
        }
        if let viewModelForAction = cellViewModel(for: indexPath) {
            output.didTapAction(actionType: actionType, viewModel: viewModelForAction)
        }
    }
}

// MARK: - UITableViewDelegate

extension ChainAssetListViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tokenRow(at: indexPath) != nil {
            activateTokenRow(at: indexPath)
            return
        }
        guard let viewModel = cellViewModel(for: indexPath) else { return }

        output.didSelectViewModel(viewModel)
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        93
    }
}

// MARK: - UITableViewDataSource

extension ChainAssetListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        max(tokenSectionCount + visibleNetworkSections.count, 1)
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < tokenSectionCount { return tokenRows(in: section).count }
        guard let networkSection = visibleNetworkSections[safe: section - tokenSectionCount] else {
            return viewModel?.displayState.rows.count ?? .zero
        }

        return collapsedNetworkSectionIds.contains(networkSection.id) ? 0 : networkSection.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if case let .token(row) = tokenRow(at: indexPath), !row.model.isSingleNetwork,
           let cell = tableView.dequeueReusableCellWithType(TokenGroupBalanceTableCell.self),
           let walletId = presentationWalletId {
            cell.delegate = self
            cell.bind(row, expanded: expandedTokenIds.contains(row.model.id), locale: locale)
            let revision = presentationRevision
            cell.onActivate = { [weak self] in
                guard let self, self.presentationRevision == revision else { return }
                self.activateTokenRow(at: indexPath)
            }
            cell.onAction = { [weak self] action in
                guard let self, self.presentationRevision == revision else { return }
                self.tokenAction(action, row: row, walletId: walletId)
            }
            return cell
        }
        if case let .zeroChildren(groupId, count) = tokenRow(at: indexPath) {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.backgroundColor = .clear
            cell.textLabel?.text = String(
                format: PortfolioStrings.text("portfolio.zero_networks", locale: locale),
                count
            )
            cell.textLabel?.font = FWAppearance
                .portfolioListRestyled ? .fw(.bodyS, compatibleWith: traitCollection) : .p2Paragraph
            cell.textLabel?.textColor = UIColor(named: "fwTextSecondary")
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.adjustsFontForContentSizeCategory = true
            cell.accessibilityTraits = .button
            cell.accessibilityValue = PortfolioStrings.text(
                expandedZeroTokenIds.contains(groupId) ? "ux.expanded" : "ux.collapsed",
                locale: locale
            )
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        guard let cell = tableView.dequeueReusableCellWithType(ChainAccountBalanceTableCell.self) else {
            return UITableViewCell()
        }
        cell.delegate = self
        if let viewModel = cellViewModel(for: indexPath) {
            let indented: Bool
            if case .asset = tokenRow(at: indexPath) { indented = true } else { indented = false }
            cell.bind(to: viewModel, showsNetwork: usesTokenLens, indented: indented)
        }
        return cell
    }
}

private extension ChainAssetListViewController {
    func networkSection(at index: Int) -> AssetNetworkSectionViewModel? {
        visibleNetworkSections[safe: index - tokenSectionCount]
    }
}

extension ChainAssetListViewController {
    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if usesTokenLens, section == 1, tokenSectionCount == 2 { return UITableView.automaticDimension }
        return networkSection(at: section) == nil ? .leastNormalMagnitude : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if usesTokenLens, section == 1, tokenSectionCount == 2,
           let header = tableView
           .dequeueReusableHeaderFooterView(withIdentifier: AssetNetworkHeaderView.reuseId) as? AssetNetworkHeaderView {
            let key = viewModel?.isWalletEmpty == true ? "portfolio.empty_networks" : "portfolio.zero_tokens"
            header.bind(
                title: String(format: PortfolioStrings.text(key, locale: locale), viewModel?.zeroTokenRows.count ?? 0),
                collapsed: !zeroTokensExpanded,
                locale: locale
            )
            let revision = presentationRevision
            header.onTap = { [weak self] in
                guard let self, self.presentationRevision == revision,
                      let walletId = self.presentationWalletId else { return }
                self.zeroTokensExpanded.toggle()
                var expanded = self.collapseStore.identifiers(walletId: walletId, kind: "summary-expanded")
                if self.zeroTokensExpanded { expanded.insert("zero-tokens") } else { expanded.remove("zero-tokens") }
                self.collapseStore.setIdentifiers(expanded, walletId: walletId, kind: "summary-expanded")
                tableView.reloadData()
            }
            return header
        }
        guard
            let sectionModel = networkSection(at: section),
            let header = tableView.dequeueReusableHeaderFooterView(
                withIdentifier: AssetNetworkHeaderView.reuseId
            ) as? AssetNetworkHeaderView
        else {
            return nil
        }

        if viewModel?.isWalletEmpty == true, case .zeroNetworks = sectionModel.kind {
            header.bind(
                title: PortfolioStrings.text("portfolio.empty_networks", locale: locale),
                collapsed: collapsedNetworkSectionIds.contains(sectionModel.id),
                locale: locale
            )
        } else {
            header.bind(sectionModel, collapsed: collapsedNetworkSectionIds.contains(sectionModel.id), locale: locale)
        }
        let revision = presentationRevision
        header.onTap = { [weak self] in
            guard let self, self.presentationRevision == revision else {
                return
            }

            if self.collapsedNetworkSectionIds.contains(sectionModel.id) {
                self.collapsedNetworkSectionIds.remove(sectionModel.id)
            } else {
                self.collapsedNetworkSectionIds.insert(sectionModel.id)
            }
            if let walletId = self.presentationWalletId {
                if sectionModel.kind == .assets {
                    self.collapseStore.setIdentifiers(
                        self.collapsedNetworkSectionIds,
                        walletId: walletId,
                        kind: "network"
                    )
                } else {
                    var expanded = self.collapseStore.identifiers(walletId: walletId, kind: "summary-expanded")
                    if self.collapsedNetworkSectionIds.contains(sectionModel.id) { expanded.remove(sectionModel.id) }
                    else { expanded.insert(sectionModel.id) }
                    self.collapseStore.setIdentifiers(expanded, walletId: walletId, kind: "summary-expanded")
                }
            }
            // A zero summary adds/removes whole network sections, so reload the table atomically.
            tableView.reloadData()
        }
        return header
    }
}

final class AssetNetworkHeaderView: UITableViewHeaderFooterView {
    static let reuseId = "AssetNetworkHeaderView"

    var onTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let subtotalLabel = UILabel()
    private let chevronView = UIImageView()
    private let summaryStack = UIStackView()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        contentView.backgroundColor = R.color.colorBlack19()
        titleLabel.font = .h5Title
        titleLabel.textColor = R.color.colorWhite()
        detailLabel.font = .p2Paragraph
        detailLabel.textColor = R.color.colorLightGray()
        subtotalLabel.font = .h6Title
        subtotalLabel.textColor = R.color.colorWhite()
        subtotalLabel.textAlignment = .left
        chevronView.tintColor = R.color.colorLightGray()

        [titleLabel, detailLabel, subtotalLabel].forEach {
            $0.numberOfLines = 0
            $0.adjustsFontForContentSizeCategory = true
        }
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtotalLabel.setContentHuggingPriority(.required, for: .horizontal)
        summaryStack.addArrangedSubview(titleLabel)
        summaryStack.addArrangedSubview(subtotalLabel)
        summaryStack.spacing = 12
        let accessibleSize = UITraitCollection.current.preferredContentSizeCategory.isAccessibilityCategory
        summaryStack.axis = accessibleSize ? .vertical : .horizontal
        summaryStack.alignment = accessibleSize ? .fill : .firstBaseline
        let labels = UIStackView(arrangedSubviews: [summaryStack, detailLabel])
        labels.axis = .vertical
        labels.spacing = 4

        contentView.addSubview(labels)
        contentView.addSubview(chevronView)

        labels.snp.makeConstraints { make in
            // Preserve UIKit's autoresizing of the header's contentView.
            make.height.greaterThanOrEqualTo(20)
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview().inset(12)
            make.trailing.equalTo(chevronView.snp.leading).offset(-8)
        }
        chevronView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(14)
        }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        contentView.addGestureRecognizer(tapGesture)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateTypography()
        let accessibleSize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        summaryStack.axis = accessibleSize ? .vertical : .horizontal
        summaryStack.alignment = accessibleSize ? .fill : .firstBaseline
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTap = nil
    }

    private func updateTypography() {
        guard FWAppearance.portfolioListRestyled else { return }
        titleLabel.font = .fw(.titleS, compatibleWith: traitCollection)
        detailLabel.font = .fw(.bodyS, compatibleWith: traitCollection)
        subtotalLabel.font = .fw(.numberM, compatibleWith: traitCollection)
        [titleLabel, detailLabel, subtotalLabel].forEach { $0.lineBreakMode = .byWordWrapping }
    }

    func bind(_ viewModel: AssetNetworkSectionViewModel, collapsed: Bool, locale: Locale = .current) {
        updateTypography()
        func text(_ key: String, fallback: String) -> String {
            FWAppearance.portfolioListRestyled ? PortfolioStrings.text(key, locale: locale)
                : NSLocalizedString(key, value: fallback, comment: "")
        }
        switch viewModel.kind {
        case .assets:
            titleLabel.text = viewModel.networkName
            detailLabel.text = viewModel.syncStatus
            subtotalLabel.text = viewModel.fiatSubtotal
        case let .zeroNetworks(count):
            titleLabel.text = String(
                format: text("portfolio.zero_networks", fallback: "%d networks · no balance"),
                count
            )
            detailLabel.text = nil
            subtotalLabel.text = nil
        case .detected:
            titleLabel.text = String(
                format: text("portfolio.asset.detected_count", fallback: "Detected assets (%d)"),
                viewModel.detectedCount
            )
            detailLabel
                .text = "\(viewModel.networkName) · " +
                text("portfolio.asset.detected_review", fallback: "Review before trusting")
            subtotalLabel.text = nil
        }
        detailLabel.isHidden = detailLabel.text?.isEmpty ?? true
        subtotalLabel.isHidden = subtotalLabel.text?.isEmpty ?? true
        chevronView.image = UIImage(systemName: collapsed ? "chevron.down" : "chevron.up")
        accessibilityLabel = [titleLabel.text, subtotalLabel.text, detailLabel.text].compactMap { $0 }
            .joined(separator: ", ")
        accessibilityValue = collapsed
            ? text("ux.collapsed", fallback: "Collapsed")
            : text("ux.expanded", fallback: "Expanded")
    }

    override func accessibilityActivate() -> Bool {
        onTap?()
        return onTap != nil
    }

    func bind(title: String, collapsed: Bool, locale: Locale) {
        updateTypography()
        titleLabel.text = title
        detailLabel.isHidden = true
        subtotalLabel.isHidden = true
        chevronView.image = UIImage(systemName: collapsed ? "chevron.down" : "chevron.up")
        accessibilityLabel = title
        accessibilityValue = PortfolioStrings.text(collapsed ? "ux.collapsed" : "ux.expanded", locale: locale)
    }

    @objc private func didTap() {
        onTap?()
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension ChainAssetListViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension ChainAssetListViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let viewModel else {
            return nil
        }
        let view = rootView.viewForEmptyState(for: viewModel.displayState)
        return view
    }

    var contentViewForEmptyState: UIView {
        rootView.containerView
    }
}

// MARK: - EmptyStateDelegate

extension ChainAssetListViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModel = viewModel else { return false }
        if usesTokenLens,
           !viewModel.tokenRows.isEmpty || !viewModel.zeroTokenRows.isEmpty || !visibleNetworkSections
           .isEmpty { return false }
        return viewModel.displayState.rows.isEmpty
    }
}
