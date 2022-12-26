import UIKit

public protocol SoramitsuTableViewCellProtocol: UIView {

	func prepareForReuse()

	func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?)
}

public extension SoramitsuTableViewCellProtocol {
	func prepareForReuse() {}
}

public extension SoramitsuTableViewCellProtocol {

	func updateCellSize(with animation: UITableView.RowAnimation = .automatic) {
		guard
			let cell = superview as? UITableViewCell,
			let tableView = cell.superview as? UITableView,
			let indexPath = tableView.indexPath(for: cell) else { return }
		DispatchQueue.main.async {
			tableView.performBatchUpdates({ tableView.reloadRows(at: [indexPath], with: animation) })
		}
	}
}
