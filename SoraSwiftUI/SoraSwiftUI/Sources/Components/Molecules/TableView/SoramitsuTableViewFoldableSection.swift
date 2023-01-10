import UIKit

public protocol SoramitsuTableViewHeaderInteractable {
	func didTapHeader(isRowsFolded: Bool)
}

public protocol SoramitsuTableViewHeaderRepresentable {
	func didTapHeader(isRowsFolded: Bool)
}

public final class SoramitsuTableViewFoldableSection: SoramitsuTableViewSectionProtocol {

	public var rows: [SoramitsuTableViewItemProtocol] {
		didSet {
			// Если мы обновляем айтемы секции, когда они находятся в свёрнутом состоянии, то обращаемся не к `rows`, а к `foldedRows`
			if isRowsFolded {
				foldedRows = rows
				rows = []
			} else {
				let oldIndexes = oldValue.enumerated().map { IndexPath(row: $0.offset, section: sectionNumber) }
				let newIndexes = rows.enumerated().map { IndexPath(row: $0.offset, section: sectionNumber) }
				context?.scrollView?.sora.register(rows)
				context?.scrollView?.performBatchUpdates({
					context?.scrollView?.deleteRows(at: oldIndexes, with: .fade)
					context?.scrollView?.insertRows(at: newIndexes, with: .fade)
				})
			}
		}
	}

	public var header: SoramitsuTableViewItemProtocol?

	public var context: SoramitsuTableViewContext?

	public private(set) var foldedRows: [SoramitsuTableViewItemProtocol] = []

	private var sectionNumber: Int {
		guard let sections = context?.scrollView?.sora.sections else { return 0 }
		return sections.firstIndex(where: { $0 === self }) ?? 0
	}

	private var isRowsFolded: Bool


	private weak var tableView: SoramitsuTableView?

	public init(
		header: SoramitsuTableViewItemProtocol,
		rows: [SoramitsuTableViewItemProtocol],
		isRowsInitiallyFolded: Bool
	) {
		self.header = header
		if isRowsInitiallyFolded {
			foldedRows = rows
			self.rows = []
		} else {
			self.rows = rows
		}
		isRowsFolded = isRowsInitiallyFolded
	}


	public func heightForRow(at indexPath: IndexPath, boundingWidth: CGFloat) -> CGFloat {
		return rows[indexPath.row].itemHeight(forWidth: boundingWidth, context: context)
	}

	public func estimatedHeightForRow(at indexPath: IndexPath, boundingWidth: CGFloat) -> CGFloat? {
		return rows[indexPath.row].itemEstimatedHeight(forWidth: boundingWidth)
	}

	public func heightForHeader(in section: Int, in tableView: SoramitsuTableView) -> CGFloat {
		return header?.itemHeight(forWidth: tableView.frame.size.width, context: context) ?? 0
	}

	public func cellForRow(at indexPath: IndexPath, in tableView: SoramitsuTableView) -> UITableViewCell {
		let item = rows[indexPath.row]
		let cell = tableView.sora.dequeueCell(for: indexPath)
		(cell as? SoramitsuTableViewCellProtocol)?.set(item: item, context: context)
		return cell
	}

	public func viewForHeader(in tableView: SoramitsuTableView) -> UIView? {
		guard let header = header else { return nil }
		let identifier = String(describing: header.cellType)
		let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: identifier)
		(headerView as? SoramitsuTableViewCellProtocol)?.set(item: header, context: context)
		headerView?.addTapGesture { [weak self] recognizer in
			self?.processFolding(recognizer)
		}
		return headerView
	}

	public func didSelectRow(at indexPath: IndexPath) {
		rows[indexPath.row].itemActionTap(with: context)
	}

	public func leadingActions(at indexPath: IndexPath) -> [UIContextualAction]? {
		return rows[indexPath.row].leadingSwipeActions
	}

	public func trailingActions(at indexPath: IndexPath) -> [UIContextualAction]? {
		return rows[indexPath.row].trailingSwipeActions
	}

	public func toggleFolding() {
		processFolding()
	}

	private func processFolding(_ recognizer: SoramitsuTapGestureRecognizer? = nil) {
		guard let header = header as? SoramitsuTableViewHeaderRepresentable else { return }
		guard let tableView = context?.scrollView else {
			assertionFailure("Для использования SoramitsuTableViewFoldableSection need setup context у SoramitsuTableView")
			return
		}
		isRowsFolded = !isRowsFolded
		header.didTapHeader(isRowsFolded: isRowsFolded)
		(recognizer?.view as? SoramitsuTableViewHeaderInteractable)?.didTapHeader(isRowsFolded: isRowsFolded)
		if isRowsFolded {
			// Watch didSet observer of `rows`
			let foldedRows = rows
			rows = foldedRows
			tableView.deleteRows(
				at: foldedRows.enumerated().map { IndexPath(row: $0.offset, section: sectionNumber) },
				with: .top
			)
		} else {
			rows = foldedRows
			foldedRows = []
		}
	}

    public func canMoveRow(at indexPath: IndexPath) -> Bool {
        return rows[indexPath.row].canMove
    }
}
