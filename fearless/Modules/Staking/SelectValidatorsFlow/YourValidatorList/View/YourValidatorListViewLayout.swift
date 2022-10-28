import UIKit

final class YourValidatorListViewLayout: UIView {
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = R.color.colorBlack19()
        tableView.separatorStyle = .none
        return tableView
    }()

    let changeValidatorsButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let emptyView: EmptyView = {
        let view = EmptyView()
        view.isHidden = true
        return view
    }()

    var locale = Locale.current {
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
        addSubview(tableView)
        addSubview(changeValidatorsButton)
        addSubview(emptyView)

        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        changeValidatorsButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.hugeOffset)
        }

        emptyView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(tableView)
            make.bottom.equalTo(changeValidatorsButton.snp.top)
        }

        var insets = tableView.contentInset
        insets.bottom = UIConstants.actionHeight + UIConstants.hugeOffset + safeAreaInsets.bottom
        tableView.contentInset = insets
    }

    private func applyLocalization() {
        changeValidatorsButton.imageWithTitleView?.title = R.string.localizable.yourValidatorsChangeValidatorsTitle(
            preferredLanguages: locale.rLanguages
        )

        let emptyViewModel = EmptyViewModel(
            title: R.string.localizable.stakingSetValidatorsMessage(preferredLanguages: locale.rLanguages),
            description: ""
        )
        emptyView.bind(viewModel: emptyViewModel)
    }
}
