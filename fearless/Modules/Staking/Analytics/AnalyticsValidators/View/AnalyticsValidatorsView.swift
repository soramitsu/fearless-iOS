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

    let pageSelector = AnalyticsValidatorsPageSelector()

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

        let verticalInset = pageSelector.bounds.height
        tableView.contentInset = .init(top: 0, left: 0, bottom: verticalInset, right: 0)

        headerView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: 295))
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }

        tableView.tableHeaderView = headerView

        addSubview(pageSelector)
        pageSelector.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
}
