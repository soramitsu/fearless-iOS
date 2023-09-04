import UIKit
import SoraFoundation

protocol WalletConnectProposalViewOutput: AnyObject {
    func didLoad(view: WalletConnectProposalViewInput)
    func viewDidDisappear()
    func backButtonDidTapped()
    func approveButtonDidTapped()
    func rejectButtonDidTapped()
    func didSelectRowAt(_ indexPath: IndexPath)
}

final class WalletConnectProposalViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletConnectProposalViewLayout

    // MARK: Private properties

    private let output: WalletConnectProposalViewOutput

    private var viewModel: WalletConnectProposalViewModel?

    // MARK: - Constructor

    init(
        output: WalletConnectProposalViewOutput,
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
        view = WalletConnectProposalViewLayout()
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

    private func configureTableView() {
        rootView.tableView.backgroundColor = .clear
        rootView.tableView.separatorStyle = .none
        rootView.tableView.estimatedRowHeight = UIConstants.cellHeight64
        rootView.tableView.rowHeight = UITableView.automaticDimension
        rootView.tableView.registerClassForCell(WalletConnectProposalDetailsTableCell.self)
        rootView.tableView.registerClassForCell(WalletConnectProposalExpandableTableCell.self)
        rootView.tableView.registerClassForCell(WalletConnectProposalWalletsTableCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }

    private func bindActions() {
        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.backButtonDidTapped()
        }
        rootView.approveButton.addAction { [weak self] in
            self?.output.approveButtonDidTapped()
        }
        rootView.rejectButton.addAction { [weak self] in
            self?.output.rejectButtonDidTapped()
        }
    }

    private func updateActionButton() {
        let enabled = viewModel?.selectedWalletIds.isNotEmpty ?? false
        rootView.approveButton.set(enabled: enabled)
    }
}

// MARK: - WalletConnectProposalViewInput

extension WalletConnectProposalViewController: WalletConnectProposalViewInput {
    func didReceive(viewModel: WalletConnectProposalViewModel) {
        self.viewModel = viewModel
        if let indexPath = viewModel.indexPath {
            rootView.tableView.reloadRows(at: [indexPath], with: .automatic)
        } else {
            rootView.tableView.reloadData()
        }
        updateActionButton()
    }
}

// MARK: - Localizable

extension WalletConnectProposalViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UITableViewDataSource

extension WalletConnectProposalViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.cells.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel?.cells[safe: indexPath.row] else {
            return UITableViewCell()
        }

        var cell: UITableViewCell?
        switch viewModel {
        case .dAppInfo, .requiredNetworks, .optionalNetworks:
            cell = tableView.dequeueReusableCellWithType(WalletConnectProposalDetailsTableCell.self)
        case .requiredExpandable, .optionalExpandable:
            cell = tableView.dequeueReusableCellWithType(WalletConnectProposalExpandableTableCell.self)
        case .wallet:
            cell = tableView.dequeueReusableCellWithType(WalletConnectProposalWalletsTableCell.self)
        }

        switch viewModel {
        case let .dAppInfo(viewModel):
            guard let cell = cell as? WalletConnectProposalDetailsTableCell else {
                return UITableViewCell()
            }
            cell.dropTriangleImageView.isHidden = true
            cell.bind(viewModel: viewModel)
        case let .requiredExpandable(viewModel):
            guard let cell = cell as? WalletConnectProposalExpandableTableCell else {
                return UITableViewCell()
            }
            cell.locale = selectedLocale
            cell.bind(viewModel: viewModel)
        case let .optionalExpandable(viewModel):
            guard let cell = cell as? WalletConnectProposalExpandableTableCell else {
                return UITableViewCell()
            }
            cell.locale = selectedLocale
            cell.bind(viewModel: viewModel)
        case let .wallet(viewModel):
            guard let cell = cell as? WalletConnectProposalWalletsTableCell else {
                return UITableViewCell()
            }
            cell.bind(viewModel: viewModel)
        case let .requiredNetworks(viewModel):
            guard let cell = cell as? WalletConnectProposalDetailsTableCell else {
                return UITableViewCell()
            }
            cell.dropTriangleImageView.isHidden = true
            cell.bind(viewModel: viewModel)
        case let .optionalNetworks(viewModel):
            guard let cell = cell as? WalletConnectProposalDetailsTableCell else {
                return UITableViewCell()
            }
            cell.dropTriangleImageView.isHidden = false
            cell.bind(viewModel: viewModel)
        }

        guard let cell = cell else {
            return UITableViewCell()
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension WalletConnectProposalViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let viewModel = viewModel?.cells[safe: indexPath.row] else {
            return UITableView.automaticDimension
        }

        switch viewModel {
        case let .requiredExpandable(cellViewModel):
            return cellViewModel.isExpanded ? UITableView.automaticDimension : UIConstants.cellHeight
        case let .optionalExpandable(cellViewModel):
            return cellViewModel.isExpanded ? UITableView.automaticDimension : UIConstants.cellHeight
        default:
            return UITableView.automaticDimension
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        output.didSelectRowAt(indexPath)
    }
}
