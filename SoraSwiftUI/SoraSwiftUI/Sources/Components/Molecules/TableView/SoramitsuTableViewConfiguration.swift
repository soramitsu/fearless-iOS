import UIKit

public class SoramitsuTableViewConfiguration<Type: SoramitsuTableView, SectionItemType: SoramitsuTableViewSection>: SoramitsuScrollViewConfiguration<Type> {

	public var sections: [SoramitsuTableViewSectionProtocol] = [] {
		didSet {
			registerCells()
			updateContextInSections()

			if !oldValue.isEmpty, let oldValue: [AnyHashable] = oldValue as? [AnyHashable], let sections = sections as? [AnyHashable] {
				let result = oldValue.getDifference(form: sections)

				let removedIndexes = IndexSet(result.removed.map { $0.offset })
				let insertedIndexes = IndexSet(result.inserted.map { $0.offset })

				self.owner?.performBatchUpdates({
					self.owner?.deleteSections(removedIndexes, with: .fade)
					self.owner?.insertSections(insertedIndexes, with: .fade)
				}, completion: {_ in
					self.owner?.layoutIfNeeded()
				})
			} else {
				self.owner?.reloadData()
			}
		}
	}

	public var context: SoramitsuTableViewContext? {
		didSet {
			updateContextInSections()
		}
	}

	public var estimatedRowHeight: CGFloat? {
		didSet {
			owner?.estimatedRowHeight = estimatedRowHeight ?? 0
		}
	}

	public var tableViewHeader: UIView? {
		didSet {
			owner?.tableHeaderView = tableViewHeader
		}
	}

	public var tableViewFooter: UIView? {
		didSet {
			owner?.tableFooterView = tableViewFooter
		}
	}

	public var separatorColor: SoramitsuColor? {
		didSet {
			if let separatorColor = separatorColor {
				owner?.separatorStyle = .singleLine
				owner?.separatorColor = style.palette.color(separatorColor)
			} else {
				owner?.separatorColor = nil
				owner?.separatorStyle = .none
			}
		}
	}

	public var handleKeyboardInset: Bool = false {
		didSet {
			if handleKeyboardInset {
				guard let owner = owner else { return }
				contentInsetsHelper = ScrollViewContentInsetsHelper(scrollView: owner)
			} else {
				contentInsetsHelper = nil
			}
		}
	}

	public weak var paginationHandler: SoramitsuTableViewPaginationHandlerProtocol? {
		didSet {
			originalSections = nil
			updatePagination()
			owner?.updateRefreshControl()
		}
	}

	public var paginationIndicator: SoramitsuLoadingIndicatable {
		didSet {
			paginationIndicator.translatesAutoresizingMaskIntoConstraints = true
		}
	}

	public var cancelsTouchesOnDragging: Bool = false

	public var showPaginationLoaderAfterReset: Bool = false

	private var originalSections: NSRange?
	private var paginator: SoramitsuTableViewPaginator?

	private var contentInsetsHelper: ScrollViewContentInsetsHelper?

	override init(style: SoramitsuStyle) {
		let indicator = SoramitsuActivityIndicatorView(style: style)
		indicator.sora.useAutoresizingMask = true
		paginationIndicator = indicator
		super.init(style: style)
	}

	public func update(_ updatedSections: [SoramitsuTableViewSectionProtocol],
					   from startIndex: Int,
					   with animation: UITableView.RowAnimation) {
		let endIndex = startIndex + updatedSections.count - 1
		guard
			!updatedSections.isEmpty,
			startIndex >= 0,
			endIndex < sections.count else { return }

		let range = startIndex ... endIndex
		let set = IndexSet(integersIn: range)
		sections.replaceSubrange(range, with: updatedSections)
		owner?.reloadSections(set, with: animation)
	}

	public func dequeueCell(for indexPath: IndexPath) -> UITableViewCell {
		let row = sections[indexPath.section].rows[indexPath.row]
		let cell = owner?.dequeueReusableCell(withIdentifier: row.reuseId(), for: indexPath)
		cell?.selectionStyle = row.isHighlighted ? .default : .none
		cell?.accessibilityLabel = row.accessibilityLabel
		cell?.accessibilityHint = row.accessibilityHint
		cell?.accessibilityIdentifier = row.accessibilityIdentifier
		cell?.accessibilityTraits = row.accessibilityTraits
		cell?.isAccessibilityElement = row.isAccessibilityElement
		cell?.accessibilityElementsHidden = row.accessibilityElementsHidden
		if let gcell = cell as? SoramitsuTableViewCell {
			gcell.sora.clipsToBounds = row.clipsToBounds
			gcell.sora.backgroundColor = row.backgroundColor
			gcell.sora.selectionColor = row.selectionColor
		}
		return cell ?? UITableViewCell()
	}

	public override func styleDidChange(options: UpdateOptions) {
		super.styleDidChange(options: options)

		if options.contains(.all) {
			retrigger(self, \.sections)
		}
	}

	public func requestNextPage() {
		paginator?.requestNextPageIfAvailable(pageType: .bottom)
	}

	public func scrollToTop() {
		guard !sections.isEmpty else { return }
		let indexPath = IndexPath(row: NSNotFound, section: 0)
		owner?.scrollToRow(at: indexPath, at: .top, animated: true)
	}

	@objc func updatePagination() {
		if let paginationHandler = paginationHandler {
			paginator = SoramitsuTableViewPaginator(handler: paginationHandler)
			paginator?.delegate = self
			paginator?.start()
		}
		if let originalSections = originalSections, let range = Range(originalSections) {
			sections = Array(sections[range])
		}
		originalSections = nil
	}

	public func appendPageOnTop(items: [SoramitsuTableViewItemProtocol], resetPages: Bool) {
		// Пересоздаем пагинатор, но не запускаем его
		if resetPages {
			if let paginationHandler = paginationHandler {
				paginator = SoramitsuTableViewPaginator(handler: paginationHandler)
				paginator?.delegate = self
			}
			if let originalSections = originalSections, let range = Range(originalSections) {
				sections = Array(sections[range])
			}
		}
		paginator?.appendPageOnTop(with: items)
	}

	override func configureOwner() {
		super.configureOwner()
		retrigger(self, \.sections)
		retrigger(self, \.context)
		retrigger(self, \.estimatedRowHeight)
		retrigger(self, \.showsVerticalScrollIndicator)
		retrigger(self, \.tableViewHeader)
		retrigger(self, \.tableViewFooter)
		retrigger(self, \.separatorColor)
		retrigger(self, \.handleKeyboardInset)
	}

	private func registerCells() {
		for section in sections {
			register(section)
			if let section = section as? SoramitsuTableViewFoldableSection { register(section.foldedRows) }
		}
	}

	private func updateContextInSections() {
		sections.forEach { $0.context = context }
	}

	func register(_ items: [SoramitsuTableViewItemProtocol]) {
		items.forEach { self.owner?.register($0.cellType, forCellReuseIdentifier: $0.reuseId()) }
	}

	func register(_ section: SoramitsuTableViewSectionProtocol) {
		if let header = section.header {
			owner?.register(header.cellType, forHeaderFooterViewReuseIdentifier: header.reuseId())
		}
		register(section.rows)
	}

	public func doesHaveAnyRows() -> Bool {
		return sections.reduce(into: 0) { totalCount, section in totalCount += section.rows.count } > 0
	}
}

private extension SoramitsuTableViewItemProtocol {

	func reuseId() -> String {
		return String(describing: cellType)
	}
}

extension SoramitsuTableViewConfiguration: SoramitsuTableViewPaginatorDelegate {

	func reloadEmptyView() {
		owner?.reloadEmptyView()
	}

	func endRefreshing() {
		owner?.refreshControl?.endRefreshing()
	}

	func addLoadingIndicator(position: PagePosition) {
		if !doesHaveAnyRows() && !showPaginationLoaderAfterReset { return }
		owner?.performWithoutScrolling(changingRows: false) {
			owner?.addLoadingIndicator(position: position)
		}
	}

	func removeLoadingIndicator(position: PagePosition) {
		owner?.removeLoadingIndicator(position: position)
	}

	func appendSections(_ sections: [SoramitsuTableViewSectionProtocol], position: PagePosition) {

		if originalSections == nil {
			originalSections = NSRange(location: 0, length: self.sections.count)
		}

		guard !sections.isEmpty else { return }

		switch position {
		case .bottom:
			self.sections.append(contentsOf: sections)
		case .top:
			owner?.performWithoutScrolling(changingRows: true) {
				self.sections.insert(contentsOf: sections, at: .zero)
			}
			originalSections?.location += sections.count
		}
	}

	func appendItems(_ items: [SoramitsuTableViewItemProtocol], position: PagePosition) {
		switch position {
		case .bottom:
			self.sections.last?.rows.append(contentsOf: items)
		case .top:
			owner?.performWithoutScrolling(changingRows: true) {
				self.sections.first?.rows.insert(contentsOf: items, at: .zero)
				self.owner?.reloadData()
			}
		}
	}

	func addItemsOnTop(_ items: [SoramitsuTableViewItemProtocol], position: PagePosition) {
		self.register(items)

		switch position {
		case .bottom:
			var originalSectionCount = 0
			if let originalSections = originalSections, let range = Range(originalSections) {
				originalSectionCount = range.count
			}
			self.sections.dropFirst(originalSectionCount).first?.rows.insert(contentsOf: items, at: .zero)
		case .top:
			self.sections.first?.rows.insert(contentsOf: items, at: .zero)
		}
		UIView.performWithoutAnimation {
			self.owner?.reloadData()
		}
	}

	func handlePagination(position: PagePosition) {
		paginator?.requestNextPageIfAvailable(pageType: position)
	}
}
