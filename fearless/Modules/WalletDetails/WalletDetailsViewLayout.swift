import UIKit
import SnapKit

final class WalletDetailsViewLayout: UIView {
    var walletView: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.titleLabel.font = .p1Paragraph
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.iconView.image = R.image.iconBirdGreen()
        view.strokeColor = R.color.colorWhite8()!
        view.borderWidth = 1
        view.layout = .singleTitle
        return view
    }()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = R.color.colorBlack19()
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
        navBar.set(.push)
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
        walletView.title = viewModel.walletName
        walletView.isHidden = false
    }

    func bind(to viewModel: WalletExportViewModel) {
        navigationLabel.text = viewModel.navigationTitle
        walletView.title = viewModel.walletName
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
    func setupLayout() {
        backgroundColor = R.color.colorBlack19()

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
            make.height.equalTo(72)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(walletView.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
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
