import UIKit
import SnapKit

final class StakingPayoutConfirmationViewLayout: UIView {
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = R.color.colorBlack()
        tableView.separatorColor = R.color.colorDarkGray()
        return tableView
    }()

    let transferConfirmView: TransferConfirmAccessoryView! = {
        UINib(resource: R.nib.transferConfirmAccessoryView)
            .instantiate(withOwner: nil, options: nil)[0] as? TransferConfirmAccessoryView
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
        let separator = UIView()
        separator.backgroundColor = R.color.colorDarkGray()
        addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1 / UIScreen.main.scale)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }

        let transferHeight = 136 - safeAreaInsets.bottom
        addSubview(transferConfirmView)
        transferConfirmView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(transferHeight)
        }
    }
}
