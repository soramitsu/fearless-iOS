import UIKit
import CommonWallet
import RobinHood
import SoraUI
import SoraFoundation

private struct NavigationItemState {
    var title: String?
    var leftBarItem: UIBarButtonItem?
    var rightBarItem: UIBarButtonItem?
}

final class WalletTransactionHistoryViewController: UIViewController, ViewHolder {
    private enum Constants {
        static let headerHeight: CGFloat = 45.0
        static let sectionHeight: CGFloat = 20.0
        static let compactTitleLeft: CGFloat = 20.0
        static let multiplierToActivateNextLoading: CGFloat = 1.5
        static let draggableProgressStart: Double = 0.0
        static let draggableProgressFinal: Double = 1.0
        static let triggerProgressThreshold: Double = 0.8
        static let loadingViewMargin: CGFloat = 4.0
        static let bouncesThreshold: CGFloat = 1.0
        static let historyContainerCornerRadius: CGFloat = 6.0
    }

    typealias RootViewType = WalletTransactionHistoryViewLayout

    let presenter: WalletTransactionHistoryPresenterProtocol

    private var state: WalletTransactionHistoryViewState = .loading

    private var draggableState: DraggableState = .compact
    private var compactInsets: UIEdgeInsets = .zero
    private var fullInsets: UIEdgeInsets = .zero

    var headerType: HistoryHeaderType = .bar

    weak var delegate: DraggableDelegate?

    weak var reloadableDelegate: ReloadableDelegate?

    private var previousNavigationItemState: NavigationItemState?

    private var didSetupLayout: Bool = false

    init(
        presenter: WalletTransactionHistoryPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletTransactionHistoryViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        setupLocalization()

        rootView.closeButton.addTarget(
            self,
            action: #selector(closeButtonClicked),
            for: .touchUpInside
        )

        rootView.filterButton.addTarget(
            self,
            action: #selector(filtersButtonClicked),
            for: .touchUpInside
        )

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(WalletTransactionHistoryCell.self)
        rootView.tableView.separatorStyle = .none
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.titleLabel.text = R.string.localizable.transactionListHeader(preferredLanguages: languages)
    }

    private func updateLoadingAndEmptyState(animated: Bool) {
        updateEmptyState(animated: animated)
    }

    func applyState(_: WalletTransactionHistoryViewState) {
        switch state {
        case .loading:
            rootView.tableView.isHidden = true
        case let .loaded(viewModel):
            handle(changes: viewModel.lastChanges)
            rootView.tableView.isHidden = viewModel.sections.isEmpty
        case let .reloaded(viewModel):
            state = .loaded(viewModel: viewModel)
            reloadContent()
            rootView.tableView.isHidden = viewModel.sections.isEmpty
        case .unsupported:
            rootView.tableView.isHidden = false
            reloadContent()
        }

        updateLoadingAndEmptyState(animated: true)
    }

    private func handle(changes: [WalletTransactionHistoryChange]) {
        if !changes.isEmpty {
            rootView.tableView.beginUpdates()

            changes.forEach { self.applySection(change: $0) }

            rootView.tableView.endUpdates()
        }
    }

    private func applySection(change: WalletTransactionHistoryChange) {
        switch change {
        case let .insert(index, _):
            rootView.tableView.insertSections([index], with: .fade)
        case let .update(sectionIndex, itemChange, _):
            applyRow(change: itemChange, for: sectionIndex)
        case let .delete(index, _):
            rootView.tableView.deleteSections([index], with: .fade)
        }
    }

    private func applyRow(change: ListDifference<WalletTransactionHistoryCellViewModel>, for sectionIndex: Int) {
        switch change {
        case let .insert(index, _):
            rootView.tableView.insertRows(at: [IndexPath(row: index, section: sectionIndex)], with: .fade)
        case let .update(index, _, _):
            rootView.tableView.reloadRows(at: [IndexPath(row: index, section: sectionIndex)], with: .fade)
        case let .delete(index, _):
            rootView.tableView.deleteRows(at: [IndexPath(row: index, section: sectionIndex)], with: .fade)
        }
    }

    @objc private func closeButtonClicked() {
        if draggableState == .full {
            delegate?.wantsTransit(to: .compact, animating: true)
        }
    }

    @objc private func filtersButtonClicked() {
        presenter.didTapFiltersButton()
    }
}

extension WalletTransactionHistoryViewController: WalletTransactionHistoryViewProtocol {
    func didReceive(state: WalletTransactionHistoryViewState) {
        self.state = state
        applyState(state)
    }

    func reloadContent() {
        rootView.tableView.reloadData()
        updateLoadingAndEmptyState(animated: true)
    }
}

extension WalletTransactionHistoryViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        print("[transaction_history] numberOfSections: \(viewModel.sections.count)")

        return viewModel.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        print("[transaction_history] numberOfRowsInSection: \(viewModel.sections[section].items.count)")
        return viewModel.sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        let sectionViewModel = viewModel.sections[indexPath.section]
        let itemViewModel = sectionViewModel.items[indexPath.row]

        guard let cell = tableView.dequeueReusableCellWithType(WalletTransactionHistoryCell.self) else {
            return UITableViewCell()
        }

        cell.bind(to: itemViewModel)

        return cell
    }
}

extension WalletTransactionHistoryViewController: UITableViewDelegate {
    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .loaded(viewModel) = state else {
            return nil
        }

        let view = WalletTransactionHistoryTableSectionHeader()
        view.bind(to: viewModel.sections[section])
        return view
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        Constants.sectionHeight
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard case let .loaded(viewModel) = state else {
            return
        }

        let sectionViewModel = viewModel.sections[indexPath.section]
        let itemViewModel = sectionViewModel.items[indexPath.row]

        tableView.deselectRow(at: indexPath, animated: true)
        presenter.didSelect(viewModel: itemViewModel)
//        let items = presenter.sectionModel(at: indexPath.section).items
//        try? items[indexPath.row].command?.execute()
    }
}

extension WalletTransactionHistoryViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        handleDraggableOnScroll(scrollView: scrollView)
        handleNextPageOnScroll(scrollView: scrollView)
    }

    private func handleDraggableOnScroll(scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < Constants.bouncesThreshold {
            scrollView.bounces = false
            scrollView.showsVerticalScrollIndicator = false
        } else {
            scrollView.bounces = true
            scrollView.showsVerticalScrollIndicator = true
        }
    }

    private func handleNextPageOnScroll(scrollView: UIScrollView) {
        var threshold = scrollView.contentSize.height
        threshold -= scrollView.bounds.height * Constants.multiplierToActivateNextLoading

        if scrollView.contentOffset.y > threshold {
            if presenter.loadNext() {
//                pageLoadingView.start()
            } else {
//                pageLoadingView.stop()
            }
        }
    }
}

extension WalletTransactionHistoryViewController: Draggable {
    var draggableView: UIView {
        view
    }

    var scrollPanRecognizer: UIPanGestureRecognizer? {
        rootView.tableView.panGestureRecognizer
    }

    func canDrag(from state: DraggableState) -> Bool {
        switch state {
        case .compact:
            return true
        case .full:
            return !(rootView.tableView.contentOffset.y > 0.0)
        }
    }

    func set(dragableState: DraggableState, animated: Bool) {
        let oldState = dragableState
        draggableState = dragableState

        if animated {
            animate(
                progress: Constants.draggableProgressFinal,
                from: oldState,
                to: dragableState,
                finalFrame: draggableView.frame
            )
        } else {
            update(for: dragableState, progress: Constants.draggableProgressFinal, forcesLayoutUpdate: didSetupLayout)
        }

        updateTableViewAfterTransition(to: dragableState, animated: animated)

        if case .hidden = headerType {
            updateHiddenTypeNavigationItem(for: dragableState, animated: animated)
        }
    }

    func set(contentInsets: UIEdgeInsets, for state: DraggableState) {
        switch state {
        case .compact:
            compactInsets = contentInsets
        case .full:
            fullInsets = contentInsets
        }

        if draggableState == state {
            applyContentInsets(for: draggableState)
            update(for: draggableState, progress: Constants.draggableProgressFinal, forcesLayoutUpdate: didSetupLayout)
        }
    }

    func animate(progress: Double, from _: DraggableState, to newState: DraggableState, finalFrame: CGRect) {
        UIView.beginAnimations(nil, context: nil)

        draggableView.frame = finalFrame
        updateHeaderHeight(for: newState, progress: progress, forcesLayoutUpdate: didSetupLayout)
        updateContent(for: newState, progress: progress, forcesLayoutUpdate: didSetupLayout)

        UIView.commitAnimations()
    }

    fileprivate func update(for draggableState: DraggableState, progress: Double, forcesLayoutUpdate: Bool) {
        updateContent(for: draggableState, progress: progress, forcesLayoutUpdate: forcesLayoutUpdate)
        updateHeaderHeight(for: draggableState, progress: progress, forcesLayoutUpdate: forcesLayoutUpdate)
    }

    fileprivate func updateContent(for draggableState: DraggableState, progress: Double, forcesLayoutUpdate: Bool) {
        switch headerType {
        case .bar:
            updateBarTypeContent(for: draggableState, progress: progress, forcesLayoutUpdate: forcesLayoutUpdate)
        case .hidden:
            updateHiddenTypeContent(for: draggableState, progress: progress, forcesLayoutUpdate: forcesLayoutUpdate)
        }
    }

    fileprivate func updateBarTypeContent(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        switch draggableState {
        case .compact:
            let adjustedProgress = min(progress / (1.0 - Constants.triggerProgressThreshold), 1.0)

            rootView.closeButton.alpha = CGFloat(1.0 - adjustedProgress)
            rootView.panIndicatorView.alpha = CGFloat(adjustedProgress)
            rootView.backgroundImageView.alpha = CGFloat(1.0 - adjustedProgress)
            rootView.update(tableViewOffset: CGFloat(adjustedProgress) * 16.0)

            if progress > 0.0 {
                rootView.tableView.isScrollEnabled = false
            }

        case .full:
            let adjustedProgress = max(progress - Constants.triggerProgressThreshold, 0.0)
                / (1.0 - Constants.triggerProgressThreshold)

            rootView.closeButton.alpha = CGFloat(adjustedProgress)
            rootView.panIndicatorView.alpha = CGFloat(1.0 - adjustedProgress)
            rootView.backgroundImageView.alpha = CGFloat(adjustedProgress)
            rootView.update(tableViewOffset: CGFloat(1.0 - adjustedProgress) * 16.0)
        }

        if forcesLayoutUpdate {
            view.layoutIfNeeded()
        }
    }

    fileprivate func updateHiddenTypeContent(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        switch draggableState {
        case .compact:
            let adjustedProgress = min(progress / (1.0 - Constants.triggerProgressThreshold), 1.0)

            rootView.closeButton.alpha = 0.0
            rootView.headerView.alpha = CGFloat(adjustedProgress)
            rootView.panIndicatorView.alpha = CGFloat(adjustedProgress)
            rootView.backgroundImageView.alpha = CGFloat(1.0 - adjustedProgress)

            if progress > 0.0 {
                rootView.tableView.isScrollEnabled = false
            }
        case .full:
            let adjustedProgress = max(progress - Constants.triggerProgressThreshold, 0.0)
                / (1.0 - Constants.triggerProgressThreshold)

            rootView.closeButton.alpha = 0.0
            rootView.headerView.alpha = CGFloat(1.0 - adjustedProgress)
            rootView.panIndicatorView.alpha = CGFloat(1.0 - adjustedProgress)
            rootView.backgroundImageView.alpha = CGFloat(adjustedProgress)
        }

        if forcesLayoutUpdate {
            view.layoutIfNeeded()
        }
    }

    fileprivate func updateTableViewAfterTransition(to state: DraggableState, animated: Bool) {
        switch state {
        case .compact:
            rootView.tableView.setContentOffset(.zero, animated: animated)
            rootView.tableView.showsVerticalScrollIndicator = false
            rootView.closeButton.isHidden = true
        case .full:
            rootView.tableView.isScrollEnabled = true
            rootView.closeButton.isHidden = false
        }
    }

    private func updateHeaderHeight(for draggableState: DraggableState, progress: Double, forcesLayoutUpdate: Bool) {
        switch headerType {
        case .bar:
            updateBarTypeHeaderHeight(
                for: draggableState,
                progress: progress,
                forcesLayoutUpdate: forcesLayoutUpdate
            )
        case .hidden:
            updateHiddenTypeHeaderHeight(
                for: draggableState,
                progress: progress,
                forcesLayoutUpdate: forcesLayoutUpdate
            )
        }
    }

    private func updateBarTypeHeaderHeight(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        let cornerRadius = Constants.historyContainerCornerRadius

        switch draggableState {
        case .compact:
            let adjustedProgress = min(progress / (1.0 - Constants.triggerProgressThreshold), 1.0)

            rootView.setHeaderTopOffset(CGFloat(1.0 - adjustedProgress) * (fullInsets.top - cornerRadius) + cornerRadius)
        case .full:
            let adjustedProgress = max(progress - Constants.triggerProgressThreshold, 0.0)
                / (1.0 - Constants.triggerProgressThreshold)

            rootView.setHeaderTopOffset(CGFloat(adjustedProgress) * (fullInsets.top - cornerRadius) + cornerRadius)
        }

        if forcesLayoutUpdate {
            view.layoutIfNeeded()
        }
    }

    private func updateHiddenTypeHeaderHeight(
        for draggableState: DraggableState,
        progress: Double,
        forcesLayoutUpdate: Bool
    ) {
        let cornerRadius = Constants.historyContainerCornerRadius

        switch draggableState {
        case .compact:
            let adjustedProgress = min(progress / (1.0 - Constants.triggerProgressThreshold), 1.0)

            rootView.setHeaderTopOffset(CGFloat(1.0 - adjustedProgress) * (fullInsets.top - cornerRadius) + cornerRadius)
            rootView.setHeaderHeight(Constants.headerHeight * CGFloat(adjustedProgress) +
                fullInsets.top * CGFloat(1.0 - adjustedProgress))
        case .full:
            let adjustedProgress = max(progress - Constants.triggerProgressThreshold, 0.0)
                / (1.0 - Constants.triggerProgressThreshold)

            rootView.setHeaderHeight(Constants.headerHeight * CGFloat(1.0 - adjustedProgress) +
                fullInsets.top * CGFloat(adjustedProgress))
            rootView.setHeaderTopOffset(CGFloat(1.0 - adjustedProgress) * (fullInsets.top - cornerRadius) + cornerRadius)
        }

        if forcesLayoutUpdate {
            view.layoutIfNeeded()
        }
    }

    private func setupNavigationItemTitle(_ item: UINavigationItem) {
        item.title = L10n.History.title
    }

    private func updateHiddenTypeNavigationItem(for state: DraggableState, animated _: Bool) {
        guard
            let navigationItem = delegate?.presentationNavigationItem else {
            return
        }

        switch state {
        case .compact:
            if let state = previousNavigationItemState {
                navigationItem.title = state.title
                navigationItem.leftBarButtonItem = state.leftBarItem
                navigationItem.rightBarButtonItem = state.rightBarItem

                previousNavigationItemState = nil
            }
        case .full:
            if previousNavigationItemState == nil {
                previousNavigationItemState = NavigationItemState(
                    title: navigationItem.title,
                    leftBarItem: navigationItem.leftBarButtonItem,
                    rightBarItem: navigationItem.rightBarButtonItem
                )

                setupNavigationItemTitle(navigationItem)

                let closeBarItem = UIBarButtonItem(
                    image: R.image.iconClose(),
                    style: .plain,
                    target: self,
                    action: #selector(closeButtonClicked)
                )
                navigationItem.setLeftBarButton(closeBarItem, animated: true)

                let filterItem = UIBarButtonItem(
                    image: R.image.iconClose(),
                    style: .plain,
                    target: self,
                    action: #selector(filtersButtonClicked)
                )
                navigationItem.setRightBarButton(filterItem, animated: true)
            }
        }
    }

    private func applyContentInsets(for draggableState: DraggableState) {
        switch draggableState {
        case .compact:
            rootView.tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: compactInsets.bottom, right: 0.0)
        default:
            rootView.tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: fullInsets.bottom, right: 0.0)
        }
    }
}

extension WalletTransactionHistoryViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        switch state {
        case let .loaded(viewModel):
            return viewModel.sections.isEmpty
        case .unsupported:
            return true
        default:
            return false
        }
    }
}

extension WalletTransactionHistoryViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        nil
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }

    var imageForEmptyState: UIImage? {
        R.image.iconStartSearch()
    }

    var titleForEmptyState: String? {
        if case WalletTransactionHistoryViewState.unsupported = state {
            return R.string.localizable.walletTransactionHistoryUnsupportedMessage(preferredLanguages: selectedLocale.rLanguages)
        }

        return R.string.localizable.walletTransactionHistoryEmptyMessage(preferredLanguages: selectedLocale.rLanguages)
    }

    var titleColorForEmptyState: UIColor? {
        R.color.colorAlmostWhite()
    }

    var titleFontForEmptyState: UIFont? {
        .p2Paragraph
    }

    var verticalSpacingForEmptyState: CGFloat? {
        UIConstants.bigOffset
    }

    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        .none
    }
}

extension WalletTransactionHistoryViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate {
        self
    }

    var emptyStateDataSource: EmptyStateDataSource {
        self
    }

    var displayInsetsForEmptyState: UIEdgeInsets {
        var insets = UIEdgeInsets.zero
        insets.bottom = compactInsets.bottom
        return insets
    }
}

extension WalletTransactionHistoryViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            reloadEmptyState(animated: false)

            if draggableState == .full, let navigationItem = delegate?.presentationNavigationItem {
                setupNavigationItemTitle(navigationItem)
            }

            rootView.titleLabel.text = R.string.localizable.transactionListHeader(preferredLanguages: selectedLocale.rLanguages)

            view.setNeedsLayout()
        }
    }
}
