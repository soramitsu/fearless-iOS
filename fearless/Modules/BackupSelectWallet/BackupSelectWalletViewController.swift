import UIKit
import SoraFoundation
import SoraUI

protocol BackupSelectWalletViewOutput: AnyObject {
    func didLoad(view: BackupSelectWalletViewInput)
    func didTap(on indexPath: IndexPath)
    func didBackButtonTapped()
    func didCreateNewAccountButtonTapped()
    func viewDidAppear()
    func beingDismissed()
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard navigationController?.isBeingDismissed == true else {
            return
        }
        output.beingDismissed()
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
        reloadEmptyState(animated: false)
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

// MARK: - EmptyStateViewOwnerProtocol

extension BackupSelectWalletViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension BackupSelectWalletViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarning()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = R.string.localizable.importWalletsNotFound(preferredLanguages: selectedLocale.rLanguages)
        emptyView.iconMode = .bigFilledShadow
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.container
    }
}

// MARK: - EmptyStateDelegate

extension BackupSelectWalletViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        viewModels.isEmpty
    }
}
