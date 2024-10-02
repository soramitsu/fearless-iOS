import UIKit
import SSFModels
import SoraFoundation

protocol ConnectedAccountsViewOutput: AnyObject {
    func didLoad(view: ConnectedAccountsViewInput)
    func didSelect(viewModel: ConnectedAccountsViewModel.Accounts)
    func dismiss()
    func pop()
}

enum ConnectedAccountsViewModel {
    case wallet(WalletsManagmentCellViewModel)
    case accounts([Accounts])

    struct Accounts {
        let title: String
        let count: Int?
        let ecosystem: Ecosystem
        let chains: [ChainModel]
    }
}

final class ConnectedAccountsViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = ConnectedAccountsViewLayout

    // MARK: Private properties
    private let output: ConnectedAccountsViewOutput

    private var viewModels: [ConnectedAccountsViewModel] = []

    // MARK: - Constructor
    init(
        output: ConnectedAccountsViewOutput,
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
        view = ConnectedAccountsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupTableView()
        bindActions()
    }

    // MARK: - Private methods

    private func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(WalletsManagmentTableCell.self)
        rootView.tableView.registerClassForCell(ConnectedAccountsTableCell.self)
        rootView.tableView.separatorStyle = .none
    }

    private func bindActions() {
        rootView.closeButton.addAction { [weak self] in
            self?.output.dismiss()
        }
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.pop()
        }
    }
}

// MARK: - ConnectedAccountsViewInput
extension ConnectedAccountsViewController: ConnectedAccountsViewInput {
    func didReceive(viewModels: [ConnectedAccountsViewModel]) {
        self.viewModels = viewModels
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable
extension ConnectedAccountsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITableViewDataSource

extension ConnectedAccountsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModels.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModels[section] {
        case .wallet:
            return 1
        case let .accounts(accounts):
            return accounts.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModels[indexPath.section] {
        case let .wallet(viewModel):
            guard let cell = tableView.dequeueReusableCellWithType(WalletsManagmentTableCell.self) else {
                return UITableViewCell()
            }
            cell.bind(to: viewModel)
            cell.hideScore()
            return cell
        case let .accounts(viewModels):
            let cell = tableView.dequeueReusableCellWithType(ConnectedAccountsTableCell.self, forIndexPath: indexPath)

            var position: ConnectedAccountsTableCell.Position = .middle
            if indexPath.row == 0, tableView.numberOfRows(inSection: indexPath.section) > 1 {
                position = .top
            } else if indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1 {
                position = .bottom
            }
            let viewModel = viewModels[indexPath.row]
            cell.configure(model: viewModel, position: position)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension ConnectedAccountsViewController: UITableViewDelegate {
    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModels[section] {
        case .wallet:
            return nil
        case .accounts:
            let view = ConnectedAccountsTableHeaderView()
            view.titleLabel.text = "Connected Accounts"
            return view
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch viewModels[section] {
        case .wallet:
            return 0
        case .accounts:
            return 44
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch viewModels[indexPath.section] {
        case .wallet:
            return 86
        case .accounts:
            return 48
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard
            let section = viewModels[safe: indexPath.section],
            case let .accounts(accountsModel) = section,
            let viewModel = accountsModel[safe: indexPath.row]
        else {
            return
        }
        output.didSelect(viewModel: viewModel)
    }
}
