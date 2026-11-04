import UIKit
import SoraUI

final class ProfileViewLayout: UIView {
    let tableView = UITableView()
    let secondaryTableView = UITableView()
    private(set) var usesColumns = false
    var columnsDidChange: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack()
        for table in [tableView, secondaryTableView] {
            table.backgroundColor = R.color.colorBlack()
            table.separatorStyle = .none
            table.alwaysBounceVertical = false
            table.register(
                UINib(resource: R.nib.profileTableViewCell),
                forCellReuseIdentifier: R.reuseIdentifier.profileCellId.identifier
            )
            table.register(
                UINib(resource: R.nib.profileSectionTableViewCell),
                forCellReuseIdentifier: R.reuseIdentifier.profileSectionCellId.identifier
            )
            table.registerClassForCell(WalletsManagmentTableCell.self)
            addSubview(table)
        }
        secondaryTableView.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        // The tab sidebar can change the safe area after rotation has already
        // laid out this view, without changing its bounds again.
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // iPhone keeps its one list across the whole screen.
        guard traitCollection.userInterfaceIdiom == .pad else {
            tableView.frame = bounds
            return
        }
        for table in [tableView, secondaryTableView] where table.contentInsetAdjustmentBehavior != .never {
            table.contentInsetAdjustmentBehavior = .never
        }
        let safeFrame = bounds.inset(by: safeAreaInsets)
        let columns = AdaptiveLayout.showsColumns(in: safeFrame.width, traits: traitCollection)
        let changed = columns != usesColumns
        usesColumns = columns
        secondaryTableView.isHidden = !columns
        if columns {
            let frame = safeFrame.insetBy(dx: 24, dy: 0)
            let width = (frame.width - 24) / 2
            tableView.frame = CGRect(x: frame.minX, y: frame.minY, width: width, height: frame.height)
            secondaryTableView.frame = CGRect(
                x: tableView.frame.maxX + 24, y: frame.minY, width: width, height: frame.height
            )
        } else {
            let inset = AdaptiveLayout.isRegularWidth(traitCollection)
                ? AdaptiveLayout.columnInset(containerWidth: safeFrame.width) : 0
            tableView.frame = safeFrame.insetBy(dx: inset, dy: 0)
            secondaryTableView.frame = .zero
        }
        if changed {
            columnsDidChange?()
        }
    }
}
