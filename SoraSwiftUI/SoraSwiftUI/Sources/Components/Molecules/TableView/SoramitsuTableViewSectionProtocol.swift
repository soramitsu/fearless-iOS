import UIKit

public protocol SoramitsuTableViewSectionProtocol: AnyObject {

	var header: SoramitsuTableViewItemProtocol? { get set }

	var context: SoramitsuTableViewContext? { get set }

	var rows: [SoramitsuTableViewItemProtocol] { get set }

	func heightForRow(at indexPath: IndexPath, boundingWidth: CGFloat) -> CGFloat

	func estimatedHeightForRow(at indexPath: IndexPath, boundingWidth: CGFloat) -> CGFloat?

	func heightForHeader(in section: Int, in tableView: SoramitsuTableView) -> CGFloat

	func cellForRow(at indexPath: IndexPath, in tableView: SoramitsuTableView) -> UITableViewCell

	func viewForHeader(in tableView: SoramitsuTableView) -> UIView?

	func didSelectRow(at indexPath: IndexPath)

	func leadingActions(at indexPath: IndexPath) -> [UIContextualAction]?

	func trailingActions(at indexPath: IndexPath) -> [UIContextualAction]?

    func canMoveRow(at indexPath: IndexPath) -> Bool
}
