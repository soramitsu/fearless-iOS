import UIKit
import SoraFoundation

protocol BackupSelectWalletViewOutput: AnyObject {
    func didLoad(view: BackupSelectWalletViewInput)
    func didTap(on indexPath: IndexPath)
    func didBackButtonTapped()
    func didCreateNewAccountButtonTapped()
    func viewDidAppear()
}

final class BackupSelectWalletViewController: UIViewController, ViewHolder {
    typealias RootViewType = BackupSelectWalletViewLayout

    // MARK: Private properties

    private let output: BackupSelectWalletViewOutput

    var viewModels: [String] = []

    // MARK: - Constructor

    init(
        output: BackupSelectWalletViewOutput,
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
        view = BackupSelectWalletViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        bindAction()
        configureTableView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        output.viewDidAppear()
    }

    // MARK: - Private methods

    private func bindAction() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didBackButtonTapped()
        }
        rootView.createButton.addAction { [weak self] in
            self?.output.didCreateNewAccountButtonTapped()
        }
    }

    private func configureTableView() {
        rootView.tableView.registerClassForCell(BackupSelectWalletTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }
}

// MARK: - BackupSelectWalletViewInput

extension BackupSelectWalletViewController: BackupSelectWalletViewInput {
    func didReceive(viewModels: [String]) {
        self.viewModels = viewModels
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension BackupSelectWalletViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITableViewDataSource

extension BackupSelectWalletViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(BackupSelectWalletTableCell.self) else {
            return UITableViewCell()
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension BackupSelectWalletViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? BackupSelectWalletTableCell else {
            return
        }

        cell.bind(name: viewModels[indexPath.row])
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        output.didTap(on: indexPath)
    }
}
