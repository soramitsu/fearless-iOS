import UIKit

final class WalletConnectProposalViewLayout: UIView {
    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        return bar
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = R.color.colorBlack19()
        return tableView
    }()

    let approveButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.applyEnabledStyle()
        return button
    }()

    let rejectButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.applyDisabledStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()!
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
        addSubview(tableView)

        let actionsStack = UIFactory.default.createVerticalStackView(spacing: UIConstants.defaultOffset)
        addSubview(actionsStack)
        actionsStack.addArrangedSubview(approveButton)
        actionsStack.addArrangedSubview(rejectButton)

        navigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        actionsStack.snp.makeConstraints { make in
            make.top.equalTo(tableView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
    }

    private func applyLocalization() {
        navigationBar.setTitle("Connection details")
        approveButton.imageWithTitleView?.title = "Approve"
        rejectButton.imageWithTitleView?.title = "Reject"
    }
}
