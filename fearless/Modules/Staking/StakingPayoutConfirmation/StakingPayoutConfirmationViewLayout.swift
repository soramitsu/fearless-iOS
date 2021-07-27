import UIKit
import SnapKit

final class StakingPayoutConfirmationViewLayout: UIView {
    private enum Constants {
        static let bottomViewHeight: CGFloat = 164.0
    }

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = R.color.colorBlack()
        tableView.separatorColor = R.color.colorDarkGray()
        return tableView
    }()

    let networkFeeConfirmView: NetworkFeeConfirmView = UIFactory().createNetworkFeeConfirmView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        addSubview(networkFeeConfirmView)
        networkFeeConfirmView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
}
