import UIKit

final class StakingRewardPayoutsViewLayout: UIView {

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = R.color.colorBlack()
        return tableView
    }()

    let payoutButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        addSubview(payoutButton)
        payoutButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            payoutButton.heightAnchor.constraint(equalToConstant: UIConstants.actionHeight),
            payoutButton.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: UIConstants.horizontalInset),
            payoutButton.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -UIConstants.horizontalInset),
            payoutButton.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -UIConstants.actionBottomInset)
        ])
    }
}
