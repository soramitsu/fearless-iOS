import UIKit
import SoraFoundation

protocol WalletConnectActiveSessionsViewOutput: AnyObject {
    func didLoad(view: WalletConnectActiveSessionsViewInput)
    func didSelectRowAt(_ indexPath: IndexPath)
    func backButtonDidTapped()
    func filterConnection(by text: String?)
    func createNewConnection()
}

final class WalletConnectActiveSessionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletConnectActiveSessionsViewLayout

    // MARK: Private properties

    private let output: WalletConnectActiveSessionsViewOutput

    private var viewModels: [WalletConnectActiveSessionsViewModel] = []

    // MARK: - Constructor

    init(
        output: WalletConnectActiveSessionsViewOutput,
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
        view = WalletConnectActiveSessionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
        bindActions()
    }

    // MARK: - Private methods

    private func configureTableView() {
        rootView.tableView.rowHeight = 51
        rootView.tableView.registerClassForCell(WalletConnectActiveSessionsTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }

    private func bindActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.backButtonDidTapped()
        }
        rootView.searchView.onTextDidChanged = { [weak self] text in
            self?.output.filterConnection(by: text)
        }
        rootView.createNewConnectionButton.addAction { [weak self] in
            self?.output.createNewConnection()
        }
    }
}

// MARK: - WalletConnectActiveSessionsViewInput

extension WalletConnectActiveSessionsViewController: WalletConnectActiveSessionsViewInput {
    func didReceive(viewModels: [WalletConnectActiveSessionsViewModel]) {
        self.viewModels = viewModels
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension WalletConnectActiveSessionsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITableViewDataSource

extension WalletConnectActiveSessionsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(WalletConnectActiveSessionsTableCell.self) else {
            return UITableViewCell()
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension WalletConnectActiveSessionsViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? WalletConnectActiveSessionsTableCell else {
            return
        }

        cell.bind(viewModel: viewModels[indexPath.row])
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        output.didSelectRowAt(indexPath)
    }
}
