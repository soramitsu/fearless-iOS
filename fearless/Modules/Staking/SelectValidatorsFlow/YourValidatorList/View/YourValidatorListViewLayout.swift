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

        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        changeValidatorsButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.hugeOffset)
        }

        var insets = tableView.contentInset
        insets.bottom = UIConstants.actionHeight + UIConstants.hugeOffset + safeAreaInsets.bottom
        tableView.contentInset = insets
    }

    private func applyLocalization() {
        changeValidatorsButton.imageWithTitleView?.title = R.string.localizable.yourValidatorsChangeValidatorsTitle(
            preferredLanguages: locale.rLanguages
        )
    }
}
