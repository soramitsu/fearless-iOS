import UIKit

final class WalletDetailsViewLayout: UIView {
    var walletView: CommonInputView = {
        let view = CommonInputView()
        view.animatedInputField.textField.returnKeyType = .done
        view.isHidden = true
        return view
    }()

    var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.isHidden = true
        return label
    }()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.bigOffset, right: 0)

        return view
    }()

    let navigationLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorWhite()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    lazy var navigationBar: BaseNavigationBar = {
        let navBar = BaseNavigationBar()
        navBar.set(.present)
        return navBar
    }()

    let exportButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.applyEnabledStyle()
        button.isHidden = true
        return button
    }()

    var locale: Locale? {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        configureTextField()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        exportButton.imageWithTitleView?.title = R.string.localizable.accountExportAction(preferredLanguages: locale?.rLanguages)
    }

    func bind(to viewModel: WalletDetailsViewModel) {
        navigationLabel.text = viewModel.navigationTitle
        walletView.isHidden = false
    }

    func bind(to viewModel: WalletExportViewModel) {
        subtitleLabel.text = viewModel.navigationTitle

        subtitleLabel.isHidden = false
        exportButton.isHidden = false

        tableView.contentInset = UIEdgeInsets(
            top: tableView.contentInset.top,
            left: tableView.contentInset.left,
            bottom: UIConstants.actionHeight + UIConstants.bigOffset * 2,
            right: tableView.contentInset.right
        )
    }
}

private extension WalletDetailsViewLayout {
    func configureTextField() {
        walletView.animatedInputField.textField.returnKeyType = .done
        walletView.animatedInputField.textField.textContentType = .nickname
        walletView.animatedInputField.textField.autocapitalizationType = .none
        walletView.animatedInputField.textField.autocorrectionType = .no
        walletView.animatedInputField.textField.spellCheckingType = .no
    }

    func setupLayout() {
        backgroundColor = R.color.colorBlack()

        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        navigationBar.setCenterViews([navigationLabel])

        addSubview(walletView)
        walletView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(52)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.edges.equalTo(walletView.snp.edges)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(walletView.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.hugeOffset)
        }

        addSubview(exportButton)
        exportButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.centerX.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
            make.width.equalToSuperview().inset(UIConstants.bigOffset * 2)
        }
    }
}
