import UIKit
import SnapKit

final class CrowdloanListViewLayout: UIView {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorColor = R.color.colorDarkGray()
        view.refreshControl = UIRefreshControl()
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
    }
}
