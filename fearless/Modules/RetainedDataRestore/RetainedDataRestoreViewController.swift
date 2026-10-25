import UIKit

final class RetainedDataRestoreViewController: UITableViewController, ControllerBackedProtocol {
    private let interactor: RetainedDataArchiveManaging
    private var archives: [RetainedDataArchive] = []
    private var hasLoaded = false
    private var isRequestingRestore = false

    init(interactor: RetainedDataArchiveManaging) {
        self.interactor = interactor
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = RecoveryText.string("previous_data")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: RecoveryText.string("close"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: RecoveryText.string("export"),
            style: .plain,
            target: self,
            action: #selector(exportMaterial)
        )
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
        interactor.reevaluate { [weak self] archives in
            self?.archives = archives
            self?.hasLoaded = true
            self?.tableView.reloadData()
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        archives.count
    }

    override func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        RecoveryText
            .string(hasLoaded && !isRequestingRestore ? (archives.isEmpty ? "no_archives" : "archive_message") :
                "checking")
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let archive = archives[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let date = DateFormatter.localizedString(from: archive.date, dateStyle: .medium, timeStyle: .short)
        let kind = archive.url.deletingLastPathComponent().lastPathComponent == RetainedStoreSetAside
            .userRootName ? "wallet_data" : "network_data"
        cell.textLabel?.text = RecoveryText.string(kind) + " · " + date
        cell.detailTextLabel?.text = RecoveryText.string(archive.canRestore ? "restore" : "not_ready")
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.accessoryType = archive.canRestore ? .disclosureIndicator : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !isRequestingRestore else { return }
        let archive = archives[indexPath.row]
        guard archive.canRestore else {
            RetainedDataRestoreRouter.shared.showMessage(RecoveryText.string("not_ready"), from: self)
            return
        }
        RetainedDataRestoreRouter.shared.authorizeRecovery(from: self) { [weak self] granted in
            guard granted, let self else { return }
            let alert = UIAlertController(
                title: RecoveryText.string("restore"),
                message: RecoveryText.string("restore_warning"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: RecoveryText.string("close"), style: .cancel))
            alert.addAction(UIAlertAction(title: RecoveryText.string("restore"), style: .default) { [weak self] _ in
                guard let self else { return }
                self.isRequestingRestore = true
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.frame = CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 56)
                spinner.startAnimating()
                self.tableView.tableFooterView = spinner
                self.navigationItem.rightBarButtonItem?.isEnabled = false
                self.tableView.reloadData()
                self.interactor.requestRestore(archive) { [weak self] result in
                    guard let self else { return }
                    self.isRequestingRestore = false
                    self.tableView.tableFooterView = nil
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.tableView.reloadData()
                    guard self.view.window != nil else { return }
                    let message: String
                    switch result {
                    case .success: message = RecoveryText.string("restore_queued")
                    case .failure: message = RecoveryText.string("read_failed")
                    }
                    RetainedDataRestoreRouter.shared.showMessage(message, from: self)
                }
            })
            self.present(alert, animated: true)
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func exportMaterial() {
        RetainedDataRestoreRouter.shared.showEmergencyMaterial(from: self)
    }
}
