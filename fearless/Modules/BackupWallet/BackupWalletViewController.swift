import UIKit
import SoraFoundation

protocol BackupWalletViewOutput: AnyObject {
    func didLoad(view: BackupWalletViewInput)
    func backButtonDidTapped()
    func didSelectRowAt(_ indexPath: IndexPath)
    func viewDidAppear()
}

final class BackupWalletViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupWalletViewLayout

    // MARK: Private properties

    private enum Constants {
        static let optionCellHeight: CGFloat = 48.0
        static let detailsCellHeight: CGFloat = 86.0
        static let headerInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 16, right: 16.0)
        static let tableViewFooterHeight: CGFloat = 10.0
    }

    private let output: BackupWalletViewOutput

    private var viewModel: ProfileViewModelProtocol?

    // MARK: - Constructor

    init(
        output: BackupWalletViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = BackupWalletViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: true)
        output.didLoad(view: self)
        configureTableView()
        bindActions()
    }

    override func viewDidAppear(_: Bool) {
        output.viewDidAppear()
    }

    // MARK: - Private methods

    private func bindActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.backButtonDidTapped()
        }
    }

    private func configureTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.sectionFooterHeight = UITableView.automaticDimension
        rootView.tableView.estimatedSectionFooterHeight = Constants.tableViewFooterHeight
        rootView.tableView.register(
            UINib(resource: R.nib.profileTableViewCell),
            forCellReuseIdentifier: R.reuseIdentifier.profileCellId.identifier
        )
        rootView.tableView.registerClassForCell(WalletsManagmentTableCell.self)
        rootView.tableView.alwaysBounceVertical = false
    }

    private func prepareProfileCell(
        _ tableView: UITableView,
        indexPath: IndexPath,
        with viewModel: ProfileOptionViewModelProtocol?
    ) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(
            withIdentifier: R.reuseIdentifier.profileCellId,
            for: indexPath
        ),
            let viewModel = viewModel {
            cell.bind(viewModel: viewModel)
            return cell
        } else {
            assertionFailure("Profile cell creation failed")
            return UITableViewCell()
        }
    }

    private func prepareProfileDetailsCell(
        _ tableView: UITableView,
        with viewModel: WalletsManagmentCellViewModel?
    ) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCellWithType(WalletsManagmentTableCell.self),
           let viewModel = viewModel {
            cell.bind(to: viewModel)
            return cell
        } else {
            assertionFailure("Profile details cell creation failed")
            return UITableViewCell()
        }
    }

    private func createFooterView() -> UIView {
        let footerViewText = R.string.localizable
            .backupWalletFooterViewText(preferredLanguages: selectedLocale.rLanguages)
        let container = UIView()
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite50()
        label.text = footerViewText
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }
        return container
    }
}

// MARK: - BackupWalletViewInput

extension BackupWalletViewController: BackupWalletViewInput {
    func didReceive(viewModel: ProfileViewModelProtocol) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension BackupWalletViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension BackupWalletViewController: UITableViewDataSource {
    func tableView(_: UITableView, viewForFooterInSection: Int) -> UIView? {
        guard viewForFooterInSection == 1 else {
            return nil
        }
        return createFooterView()
    }

    func tableView(_: UITableView, heightForFooterInSection: Int) -> CGFloat {
        guard heightForFooterInSection == 1 else {
            return 0
        }
        return UITableView.automaticDimension
    }

    func numberOfSections(in _: UITableView) -> Int {
        2
    }

    func tableView(_: UITableView, numberOfRowsInSection: Int) -> Int {
        switch numberOfRowsInSection {
        case 0:
            return 1
        default:
            return viewModel?.profileOptionViewModel.count ?? 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return prepareProfileDetailsCell(
                tableView,
                with: viewModel?.profileUserViewModel
            )
        default:
            let optionViewModel = viewModel?.profileOptionViewModel[indexPath.row]
            return prepareProfileCell(tableView, indexPath: indexPath, with: optionViewModel)
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return Constants.detailsCellHeight
        default:
            return Constants.optionCellHeight
        }
    }
}

extension BackupWalletViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        output.didSelectRowAt(indexPath)
    }
}
