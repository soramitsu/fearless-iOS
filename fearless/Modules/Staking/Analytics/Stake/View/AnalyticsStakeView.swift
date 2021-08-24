import UIKit

final class AnalyticsStakeView: UIView {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorStyle = .none
        return view
    }()

    let headerView = AnalyticsStakeHeaderView()

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

        headerView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: 310))
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

final class AnalyticsRewardsBaseView<Header: UIView>: UIView {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorStyle = .none
        return view
    }()

    let headerView = Header()

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

        let height = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        var headerFrame = headerView.frame

        // Comparison necessary to avoid infinite loop
        if height != headerFrame.size.height {
            headerFrame.size.height = height
            headerView.frame = headerFrame
            tableView.tableHeaderView = headerView
        }
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
