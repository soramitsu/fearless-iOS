import UIKit
import SoraFoundation

protocol WalletConnectSessionViewOutput: AnyObject {
    func didLoad(view: WalletConnectSessionViewInput)
    func viewDidDisappear()
    func closeButtonDidTapped()
    func actionButtonDidTapped()
}

final class WalletConnectSessionViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletConnectSessionViewLayout

    // MARK: Private properties

    private let output: WalletConnectSessionViewOutput

    private var viewModel: WalletConnectSessionViewModel?

    // MARK: - Constructor

    init(
        output: WalletConnectSessionViewOutput,
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
        view = WalletConnectSessionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
        bindActions()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        output.viewDidDisappear()
    }

    // MARK: - Private methods

    private func bindActions() {
        rootView.closeButton.addAction { [weak self] in
            self?.output.closeButtonDidTapped()
        }
        rootView.actionButton.addAction { [weak self] in
            self?.output.actionButtonDidTapped()
        }
    }

    private func configureTableView() {
        rootView.tableView.backgroundColor = .clear
        rootView.tableView.separatorStyle = .none
        rootView.tableView.registerClassForCell(WalletsManagmentTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }
}

// MARK: - WalletConnectSessionViewInput

extension WalletConnectSessionViewController: WalletConnectSessionViewInput {
    func didReceive(viewModel: WalletConnectSessionViewModel) {
        self.viewModel = viewModel
        rootView.bind(viewModel: viewModel)
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension WalletConnectSessionViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITableViewDataSource

extension WalletConnectSessionViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(WalletsManagmentTableCell.self) else {
            return UITableViewCell()
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension WalletConnectSessionViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
        guard
            let viewModel = viewModel,
            let cell = cell as? WalletsManagmentTableCell else {
            return
        }

        cell.bind(to: viewModel.walletViewModel)
    }
}
