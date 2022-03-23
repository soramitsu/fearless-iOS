import UIKit

final class ManageAssetsViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let navBar = BaseNavigationBar()
        navBar.set(.present)
        return navBar
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = .white
        return label
    }()

    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        return searchBar
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorColor = R.color.colorDarkGray()
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: (UIConstants.bigOffset * 2) + UIConstants.actionHeight, right: 0)

        return view
    }()

    let applyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    private func applyLocalization() {
        navigationTitleLabel.text = R.string.localizable.walletManageAssets(preferredLanguages: locale.rLanguages)
        applyButton.imageWithTitleView?.title = R.string.localizable.commonApply(preferredLanguages: locale.rLanguages)
        searchBar.placeholder = R.string.localizable.manageAssetsSearchHint(preferredLanguages: locale.rLanguages)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(searchBar)
        addSubview(tableView)
        addSubview(applyButton)

        navigationBar.setCenterViews([navigationTitleLabel])

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        searchBar.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
        }

        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(searchBar.snp.bottom).offset(UIConstants.bigOffset)
        }

        applyButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
