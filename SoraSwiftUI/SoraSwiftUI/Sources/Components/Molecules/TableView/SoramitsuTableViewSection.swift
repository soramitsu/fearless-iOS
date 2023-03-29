import UIKit

open class SoramitsuTableViewSection: SoramitsuTableViewSectionProtocol {
	private var uuid = UUID()

	public var rows: [SoramitsuTableViewItemProtocol] {
		didSet {
			guard let sections = context?.scrollView?.sora.sections else { return }
			let sectionIndex = sections.firstIndex(where: { $0 === self }) ?? 0
			context?.scrollView?.sora.register(rows)

			if let oldValue: [AnyHashable] = oldValue as? [AnyHashable], let rows = rows as? [AnyHashable] {
				let result = oldValue.getDifference(form: rows)

				let removedIndexes = result.removed.map {
					IndexPath(row: $0.offset, section: sectionIndex)
				}
				let insertedIndexes = result.inserted.map {
					IndexPath(row: $0.offset, section: sectionIndex)
				}

				context?.scrollView?.performBatchUpdates({
					context?.scrollView?.deleteRows(at: removedIndexes, with: .fade)
					context?.scrollView?.insertRows(at: insertedIndexes, with: .automatic)
				})
				context?.scrollView?.layoutIfNeeded()
			} else {
				context?.scrollView?.reloadData()
			}
		}
	}

	public var header: SoramitsuTableViewItemProtocol? {
		didSet {
			context?.scrollView?.sora.register(self)
			guard let index = context?.scrollView?.sora.sections.firstIndex(where: { section in section === self }) else { return }
			context?.scrollView?.reloadSections(IndexSet(integer: index), with: .fade)
		}
	}

	public var context: SoramitsuTableViewContext?

	public init(rows: [SoramitsuTableViewItemProtocol] = []) {
		self.rows = rows
	}

	public func heightForRow(at indexPath: IndexPath, boundingWidth: CGFloat) -> CGFloat {
		return rows[indexPath.row].itemHeight(forWidth: boundingWidth, context: context)
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

	public func estimatedHeightForRow(at indexPath: IndexPath, boundingWidth: CGFloat) -> CGFloat? {
		return rows[indexPath.row].itemEstimatedHeight(forWidth: boundingWidth)
	}

    public func canMoveRow(at indexPath: IndexPath) -> Bool {
        return rows[indexPath.row].canMove
    }
}

extension SoramitsuTableViewSection: Hashable {
	public static func == (lhs: SoramitsuTableViewSection, rhs: SoramitsuTableViewSection) -> Bool {
		return lhs.uuid == rhs.uuid
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(uuid)
	}
}
