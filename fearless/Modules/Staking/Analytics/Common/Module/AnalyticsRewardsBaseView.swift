import UIKit

final class AnalyticsRewardsBaseView<Header: UIView>: UIView {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorStyle = .none
        return view
    }()

    let headerView = Header()

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
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        tableView.tableHeaderView = headerView
    }
}
