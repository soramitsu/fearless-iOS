import UIKit
import SoraFoundation

final class NetworkIssuesNotificationViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkIssuesNotificationViewLayout

    // MARK: Private properties

    private let output: NetworkIssuesNotificationViewOutput

    private var viewModel: [NetworkIssuesNotificationCellViewModel] = [] {
        didSet {
            rootView.tableView.reloadData()
        }
    }

    // MARK: - Constructor

    init(
        output: NetworkIssuesNotificationViewOutput,
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
        view = NetworkIssuesNotificationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configure()
    }

    // MARK: - Private methods

    private func configure() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.allowsSelection = false
        rootView.tableView.registerClassForCell(NetworkIssuesNotificationTableCell.self)

        rootView.closeButton.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)
        rootView.bottomCloseButton.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func handleDismiss() {
        output.dissmis()
    }
}

// MARK: - NetworkIssuesNotificationViewInput

extension NetworkIssuesNotificationViewController: NetworkIssuesNotificationViewInput {
    func didReceive(viewModel: [NetworkIssuesNotificationCellViewModel]) {
        self.viewModel = viewModel
    }
}

// MARK: - Localizable

extension NetworkIssuesNotificationViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITableViewDataSource

extension NetworkIssuesNotificationViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(
            NetworkIssuesNotificationTableCell.self,
            forIndexPath: indexPath
        )

        return cell
    }
}

// MARK: - UITableViewDelegate

extension NetworkIssuesNotificationViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? NetworkIssuesNotificationTableCell else {
            return
        }

        cell.bind(viewModel: viewModel[indexPath.row])
        cell.delegate = self
    }
}

// MARK: - NetworkIssuesNotificationTableCellDelegate

extension NetworkIssuesNotificationViewController: NetworkIssuesNotificationTableCellDelegate {
    func didTapOnAction(with indexPath: IndexPath?) {
        output.didTapCellAction(indexPath: indexPath)
    }
}
