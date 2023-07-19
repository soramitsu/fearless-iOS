import UIKit

final class BackupWalletViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.set(.push)
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = R.color.colorBlack19()
        view.separatorStyle = .none
        return view
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
    }

    private func applyLocalization() {
        let title = R.string.localizable
            .backupWalletTitle(preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(title)
    }
}
