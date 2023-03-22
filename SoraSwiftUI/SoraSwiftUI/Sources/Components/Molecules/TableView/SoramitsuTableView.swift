import UIKit

public final class SoramitsuTableView: UITableView, Molecule {

	public enum DeleteMode {
		case `default`
		case onlyModels
	}

	public let sora: SoramitsuTableViewConfiguration<SoramitsuTableView, SoramitsuTableViewSection>

	private var loadingIndicatorShown = false {
		didSet {
			reloadEmptyView()
		}
	}

	public var emptyView: UIView? = nil {
		didSet {
			oldValue?.removeFromSuperview()
			if let view = emptyView {
				insertSubview(view, at: 0)
			}
			reloadEmptyView()
		}
	}

	public weak var scrollViewDelegate: UIScrollViewDelegate?

	fileprivate var shouldHandlePagination = true

	public weak var tableViewObserver: SoramitsuTableViewObserver?

	init(style: SoramitsuStyle, tableViewType: SoramitsuTableViewType) {
		sora = SoramitsuTableViewConfiguration(style: style)
		super.init(frame: .zero, style: tableViewType.uiType())
        sora.owner = self
		alwaysBounceVertical = false
		tableViewType.makeDescriptor().configure(self)
		dataSource = self
		delegate = self
	}

	public func reloadItems(items: [SoramitsuTableViewItemProtocol],
							with animation: UITableView.RowAnimation = .automatic) {
		let indexes = items.compactMap { sora.sections.indexPath(of: $0) }
		if !indexes.isEmpty {
			reloadRows(at: indexes, with: animation)
		}
	}
    
	public func deleteItems(items: [SoramitsuTableViewItemProtocol],
							mode: DeleteMode = .default) {
		let indexes = items.compactMap { sora.sections.indexPath(of: $0) }
		indexes.forEach {
			guard sora.sections[safe: $0.section]?.rows[safe: $0.row] != nil else { return }
			sora.sections[$0.section].rows.remove(at: $0.row)
		}
	}

	public func deleteEmptySections() {
		sora.sections.removeAll(where: { $0.rows.isEmpty })
	}

	public func scrollToItem(item: SoramitsuTableViewItemProtocol, position: UITableView.ScrollPosition, animated: Bool = false) {
		guard let indexPath = sora.sections.indexPath(of: item) else { return }
		scrollToRow(at: indexPath, at: position, animated: animated)
	}

	public func cellForItem(item: SoramitsuTableViewItemProtocol) -> UITableViewCell? {
		guard let indexPath = sora.sections.indexPath(of: item) else { return nil }
		return self.cellForRow(at: indexPath)
	}

	public override func touchesShouldCancel(in view: UIView) -> Bool {
		if sora.cancelsTouchesOnDragging && view is UIControl {
			return true
		}
		return super.touchesShouldCancel(in: view)
	}

	@available(*, unavailable)
	required public override init(frame: CGRect, style: UITableView.Style) {
		fatalError("init(frame:style:) has not been implemented")
	}

	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	public override func reloadData() {
		super.reloadData()
		reloadEmptyView()
	}

	@objc public func resetPagination() {
		sora.updatePagination()
	}

	func addLoadingIndicator(position: PagePosition) {
		sora.paginationIndicator.start()
		switch position {
		case .bottom:
			sora.tableViewFooter = sora.paginationIndicator
		case .top:
			sora.tableViewHeader = sora.paginationIndicator
		}
		loadingIndicatorShown = true
	}

	func removeLoadingIndicator(position: PagePosition) {
		sora.paginationIndicator.stop()
		switch position {
		case .bottom:
			sora.tableViewFooter = nil
		case .top:
			sora.tableViewHeader = nil
		}

		if let type = sora.paginationHandler?.paginationType {
			switch type {
			case .both:
				loadingIndicatorShown = sora.tableViewFooter != nil || sora.tableViewHeader != nil
			case .bottom:
				loadingIndicatorShown = false
			}
		}
	}

	func reloadEmptyView() {
		UIView.animate(withDuration: CATransaction.animationDuration()) {
			self.emptyView?.alpha = !self.sora.doesHaveAnyRows() && !self.loadingIndicatorShown ? 1 : 0
		}
	}

	func updateRefreshControl() {
		if let handler = sora.paginationHandler, handler.possibleToMakePullToRefresh() {
			refreshControl = UIRefreshControl()
			refreshControl?.addTarget(self, action: #selector(resetPagination), for: .valueChanged)
		} else {
			refreshControl = nil
		}
		alwaysBounceVertical = (sora.paginationHandler?.possibleToMakePullToRefresh() ?? false) || alwaysBounceVertical
	}

	private func handlePaginationIfNeeded(for indexPath: IndexPath) {
		guard shouldHandlePagination else { return }

		if isFirst(indexPath: indexPath) {
			sora.handlePagination(position: .top)
			return
		}

		if isLast(indexPath: indexPath) {
			sora.handlePagination(position: .bottom)
			return
		}
	}

	private func isFirst(indexPath: IndexPath) -> Bool {
		IndexPath(row: .zero, section: .zero) == indexPath
	}

	private func isLast(indexPath: IndexPath) -> Bool {
		let lastSection = numberOfSections
		let lastRow = numberOfRows(inSection: lastSection - 1)
		let last = IndexPath(row: lastRow - 1, section: lastSection - 1)
		return last == indexPath
	}
}

extension SoramitsuTableView: UITableViewDataSource {
	public func numberOfSections(in tableView: UITableView) -> Int {
		return sora.sections.count
	}

	public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return sora.sections[section].rows.count
	}

	public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return sora.sections[indexPath.section].cellForRow(at: indexPath, in: self)
	}

	public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard section < sora.sections.count else { return nil }
		return sora.sections[section].viewForHeader(in: self)
	}

    public func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard indexPath.section < sora.sections.count else { return false }
        return sora.sections[indexPath.section].canMoveRow(at: indexPath)
    }

    public func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        tableViewObserver?.didMoveRow(at: sourceIndexPath, to: destinationIndexPath)
    }
}

extension SoramitsuTableView: UITableViewDelegate {

	public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		guard section < sora.sections.count else { return 0 }
		return sora.sections[section].heightForHeader(in: section, in: self)
	}

	public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		guard indexPath.section < sora.sections.count else { return 0 }
		return sora.sections[indexPath.section].heightForRow(at: indexPath, boundingWidth: tableView.bounds.width)
	}

	public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
		if let height = sora.sections[indexPath.section].estimatedHeightForRow(at: indexPath, boundingWidth: tableView.bounds.width) {
			return height
		} else {
			return estimatedRowHeight
		}
	}

	public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableViewObserver?.didSelectRow(at: indexPath)

		sora.sections[indexPath.section].didSelectRow(at: indexPath)
		tableView.deselectRow(at: indexPath, animated: true)
	}

	public func tableView(_ tableView: UITableView,
						  leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard let actions = sora.sections[indexPath.section].leadingActions(at: indexPath) else { return nil }
		let config = UISwipeActionsConfiguration(actions: actions)
		return config
	}

	public func tableView(_ tableView: UITableView,
						  trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard let actions = sora.sections[indexPath.section].trailingActions(at: indexPath) else { return nil }
		let config = UISwipeActionsConfiguration(actions: actions)
		return config
	}

	public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		let trailingActionsEmpty = sora.sections[indexPath.section].trailingActions(at: indexPath)?.isEmpty ?? true
		let leadingActionsEmpty = sora.sections[indexPath.section].trailingActions(at: indexPath)?.isEmpty ?? true
		return !trailingActionsEmpty || !leadingActionsEmpty
	}

	public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		handlePaginationIfNeeded(for: indexPath)
	}

	public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
	}

	public func scrollViewDidScroll(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidScroll?(scrollView)
	}

	public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewWillBeginDragging?(scrollView)
	}

	public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidEndDecelerating?(scrollView)
	}

	public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidScrollToTop?(scrollView)
	}

	public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		scrollViewDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
	}

	public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
										  withVelocity velocity: CGPoint,
										  targetContentOffset: UnsafeMutablePointer<CGPoint>) {
		scrollViewDelegate?.scrollViewWillEndDragging?(scrollView,
													   withVelocity: velocity,
													   targetContentOffset: targetContentOffset)
	}

	public func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
		let item = sora.sections[indexPath.section].rows[indexPath.row]
		guard let actions = item.menuActions, !actions.isEmpty else { return false }
		UIMenuController.shared.menuItems = actions.map { $0.makeMenuItem() }
		UIMenuController.shared.arrowDirection = .down
		return true
	}

	public func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath,
						  withSender sender: Any?) -> Bool {
		let actions = sora.sections[indexPath.section].rows[indexPath.row].menuActions
		return actions?.map({ action -> Selector in action.selector }).contains(action) ?? false
	}

	public func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
		// Нужен для работы UIMenuController
	}
}

// MARK: - Публичные конструкторы
public extension SoramitsuTableView {

	convenience init(type: SoramitsuTableViewType = .plain,
					 configurator: ((SoramitsuTableViewConfiguration<SoramitsuTableView, SoramitsuTableViewSection>) -> Void)? = nil) {
		self.init(style: SoramitsuUI.shared.style, tableViewType: type)
		configurator?(sora)
	}

	convenience init() {
		self.init(style: SoramitsuUI.shared.style, tableViewType: .plain)
	}
}

extension SoramitsuTableView {
    
	func performWithoutScrolling(changingRows: Bool, action: () -> Void) {
		layoutIfNeeded()
		let oldOffsetY: CGFloat = contentOffset.y
		if let firstRow = sora.sections.first?.rows.first {
			let oldRect = rectForRow(at: IndexPath(row: .zero, section: .zero))
			shouldHandlePagination = false
			action()
			layoutIfNeeded()
			if let rowNewNumber = self.sora.sections.indexPath(of: firstRow) {
				let newRect = self.rectForRow(at: rowNewNumber)
				let diff = newRect.minY - oldRect.minY
				self.contentOffset.y = oldOffsetY + diff
				layoutIfNeeded()
			}
			shouldHandlePagination = true
			if changingRows {
				reloadData()
			}
		} else {
			action()
		}
	}
}
