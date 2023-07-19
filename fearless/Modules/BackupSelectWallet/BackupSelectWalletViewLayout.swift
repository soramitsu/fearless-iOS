import UIKit

final class BackupSelectWalletViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = R.color.colorBlack19()
        view.separatorStyle = .none
        return view
    }()

    let createButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        backgroundColor = R.color.colorBlack19()
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

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview()
        }

        addSubview(createButton)
        createButton.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func applyLocalization() {
        let title = R.string.localizable
            .backupSelectWalletTitle(preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(title)
        createButton.imageWithTitleView?.title = R.string.localizable
            .backupSelectWalletCreateButton(preferredLanguages: locale.rLanguages)
    }
}
