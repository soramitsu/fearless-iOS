import UIKit

open class SoramitsuTableViewCell: UITableViewCell, Atom {

	public let sora: SoramitsuTableViewCellConfiguration<SoramitsuTableViewCell>

	public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		sora = SoramitsuTableViewCellConfiguration(style: SoramitsuUI.shared.style)
		super.init(style: style, reuseIdentifier: reuseIdentifier)
        sora.owner = self
	}

	public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
		guard let tableView = superview as? SoramitsuTableView,
			let indexPath = tableView.indexPath(for: self),
			let actions = tableView.sora.sections[indexPath.section].rows[indexPath.row].menuActions,
			actions.map({ action -> Selector in action.selector }).contains(action) else {
				return super.canPerformAction(action, withSender: sender)
		}
		return true
	}

	open override func forwardingTarget(for aSelector: Selector!) -> Any? {
		guard let tableView = superview as? SoramitsuTableView,
			let indexPath = tableView.indexPath(for: self) else {
				assertionFailure("Something went wrong, check logic")
				return nil
		}
		return tableView.sora.sections[indexPath.section].rows[indexPath.row]
	}
}
