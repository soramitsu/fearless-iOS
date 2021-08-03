import UIKit

final class AnalyticsRewardsView: UIView {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorStyle = .none
        return view
    }()

    let headerView = AnalyticsRewardsHeaderView()

    let periodSelectorView = AnalyticsPeriodSelectorView()

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

        let verticalInset = periodSelectorView.bounds.height
        tableView.contentInset = .init(top: 0, left: 0, bottom: verticalInset, right: 0)

        headerView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: 330))
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }

        tableView.tableHeaderView = headerView

        addSubview(periodSelectorView)
        periodSelectorView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
