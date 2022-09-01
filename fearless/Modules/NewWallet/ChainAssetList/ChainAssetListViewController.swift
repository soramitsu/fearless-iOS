import UIKit
import SoraFoundation
import DiffableDataSources

final class ChainAssetListViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChainAssetListViewLayout

    // MARK: Private properties

    private let output: ChainAssetListViewOutput

    private var viewModel: ChainAssetListViewModel?
    private var dataSource: TableViewDiffableDataSource<ChainAssetListTableSection, ChainAccountBalanceCellViewModel>?

    // MARK: - Constructor

    init(
        output: ChainAssetListViewOutput,
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
        view = ChainAssetListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configureTableView()
    }

    // MARK: - Private methods
}

private extension ChainAssetListViewController {
    func configureTableView() {
        rootView.tableView.registerClassForCell(ChainAccountBalanceTableCell.self)
        rootView.tableView.delegate = self
        dataSource = TableViewDiffableDataSource<ChainAssetListTableSection, ChainAccountBalanceCellViewModel>(
            tableView: rootView.tableView
        ) { tableView, indexPath, model in
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: ChainAccountBalanceTableCell.self.reuseIdentifier,
                for: indexPath
            ) as? ChainAccountBalanceTableCell else {
                return UITableViewCell()
            }
            cell.bind(to: model)
            cell.delegate = self
            cell.issueDelegate = self
            return cell
        }
        dataSource?.defaultRowAnimation = .fade
    }

    func cellViewModel(for indexPath: IndexPath) -> ChainAccountBalanceCellViewModel? {
        if
            let section = viewModel?.sections[indexPath.section],
            let cellModel = viewModel?.cellsForSections[section]?[indexPath.row] {
            return cellModel
        }
        return nil
    }
}

// MARK: - ChainAssetListViewInput

extension ChainAssetListViewController: ChainAssetListViewInput {
    func didReceive(viewModel: ChainAssetListViewModel) {
        self.viewModel = viewModel
        var snapshot = DiffableDataSourceSnapshot<ChainAssetListTableSection, ChainAccountBalanceCellViewModel>()
        snapshot.appendSections(viewModel.sections)
        viewModel.sections.forEach { section in
            if let cells = viewModel.cellsForSections[section] {
                snapshot.appendItems(cells, toSection: section)
            }
        }
        dataSource?.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: - Localizable

extension ChainAssetListViewController: Localizable {
    func applyLocalization() {}
}

extension ChainAssetListViewController: SwipableTableViewCellDelegate {
    func swipeCellDidTap(on actionType: SwipableCellButtonType, with indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            return
        }
        if let viewModelForAction = cellViewModel(for: indexPath) {
            output.didTapAction(actionType: actionType, viewModel: viewModelForAction)
        }
    }
}

extension ChainAssetListViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = cellViewModel(for: indexPath) else { return }

        output.didSelectViewModel(viewModel)
    }
}

extension ChainAssetListViewController: ChainAccountBalanceTableCellDelegate {
    func issueButtonTapped(with indexPath: IndexPath?) {
        guard
            let indexPath = indexPath,
            let viewModel = cellViewModel(for: indexPath)
        else {
            return
        }

        output.didTapOnIssueButton(viewModel: viewModel)
    }
}
