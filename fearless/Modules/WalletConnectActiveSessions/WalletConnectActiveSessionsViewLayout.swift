import UIKit

final class WalletConnectActiveSessionsViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let searchView: SearchTextField = {
        UIFactory.default.createSearchTextField()
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = R.color.colorBlack19()
        return tableView
    }()

    let createNewConnectionButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        return button
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

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.backButton.rounded()
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(32)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        addSubview(createNewConnectionButton)
        createNewConnectionButton.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func applyLocalization() {
        navigationBar.setTitle(R.string.localizable.commonConnections(preferredLanguages: locale.rLanguages))
        searchView.textField.placeholder = R.string.localizable.searchByConnection(preferredLanguages: locale.rLanguages)
        createNewConnectionButton.imageWithTitleView?.title = R.string.localizable.createNewConnection(preferredLanguages: locale.rLanguages)
    }
}
