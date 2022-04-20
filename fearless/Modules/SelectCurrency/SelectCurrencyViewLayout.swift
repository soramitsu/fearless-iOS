import UIKit

final class SelectCurrencyViewLayout: UIView {
    private enum Constants {
        static let contentInset = UIEdgeInsets(
            top: UIConstants.bigOffset,
            left: 0,
            bottom: UIConstants.bigOffset,
            right: 0
        )
    }

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = R.color.colorBlack()
        tableView.contentInset = Constants.contentInset
        return tableView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack()!
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
