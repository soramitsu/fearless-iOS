import UIKit
import SnapKit

final class WalletHistoryFilterViewLayout: UIView {
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .clear
        tableView.separatorColor = R.color.colorDarkGray()
        return tableView
    }()

    let headerView: IconTitleHeaderView = {
        let view = R.nib.iconTitleHeaderView(owner: nil)!
        view.titleView.titleColor = R.color.colorWhite()
        view.titleView?.titleFont = .h4Title
        return view
    }()

    let applyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = R.color.colorBlack()
    }

    private func setupLayout() {
        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide)
        }

        headerView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.tableHeaderHeight)
        }

        tableView.tableHeaderView = headerView

        addSubview(applyButton)

        applyButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
