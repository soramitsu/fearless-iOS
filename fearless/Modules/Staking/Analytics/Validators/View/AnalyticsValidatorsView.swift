import UIKit

final class AnalyticsValidatorsView: UIView {
    let headerView = AnalyticsValidatorsHeaderView()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.tableFooterView = UIView()
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        headerView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: 319))
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        tableView.tableHeaderView = headerView
    }
}
