import UIKit

final class WalletConnectProposalViewLayout: UIView {
    private let status: WalletConnectProposalPresenter.SessionStatus

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
        tableView.tableFooterView = UIView()
        return tableView
    }()

    let mainActionButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.applyEnabledStyle()
        return button
    }()

    let rejectButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.applyDisabledStyle()
        return button
    }()

    let expiryDateView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h6Title
        view.borderView.fillColor = R.color.colorBlack19()!
        view.borderView.borderType = .none
        return view
    }()

    init(status: WalletConnectProposalPresenter.SessionStatus) {
        self.status = status
        super.init(frame: .zero)
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

    func setExpiryDate(string: String?) {
        guard let string = string else {
            return
        }
        expiryDateView.valueLabel.text = string
        expiryDateView.frame = CGRect(origin: .zero, size: CGSize(width: tableView.bounds.width, height: UIConstants.cellHeight))
        tableView.tableFooterView = expiryDateView
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(tableView)

        let actionsStack = UIFactory.default.createVerticalStackView(spacing: UIConstants.defaultOffset)
        addSubview(actionsStack)

        switch status {
        case .proposal:
            actionsStack.addArrangedSubview(mainActionButton)
            actionsStack.addArrangedSubview(rejectButton)
        case .active:
            actionsStack.addArrangedSubview(mainActionButton)
        }

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
        switch status {
        case .proposal:
            navigationBar.setTitle(R.string.localizable.connectDetails(preferredLanguages: locale.rLanguages))
            mainActionButton.imageWithTitleView?.title = R.string.localizable.commonApprove(preferredLanguages: locale.rLanguages)
            rejectButton.imageWithTitleView?.title = R.string.localizable.commonReject(preferredLanguages: locale.rLanguages)
        case .active:
            navigationBar.setTitle(R.string.localizable.connectDetails(preferredLanguages: locale.rLanguages))
            mainActionButton.imageWithTitleView?.title = R.string.localizable.commonDisconnect(preferredLanguages: locale.rLanguages)
            expiryDateView.titleLabel.text = R.string.localizable.commonExpiry(preferredLanguages: locale.rLanguages)
        }
    }
}
