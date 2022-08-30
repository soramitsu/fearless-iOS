import UIKit
import SoraFoundation

final class ChainAssetListViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChainAssetListViewLayout

    // MARK: Private properties

    private let output: ChainAssetListViewOutput

    private var sections: [ChainAssetListTableSection] = []

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

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(ChainAccountBalanceTableCell.self)
    }

    // MARK: - Private methods
}

// MARK: - ChainAssetListViewInput

extension ChainAssetListViewController: ChainAssetListViewInput {
    func didReceive(viewModel: ChainAssetListViewModel) {
        sections = viewModel.sections
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension ChainAssetListViewController: Localizable {
    func applyLocalization() {}
}

extension ChainAssetListViewController: UITableViewDelegate {
    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? ChainAccountBalanceTableCell
        else {
            return
        }

        cell.bind(to: sections[indexPath.section].cellViewModels[indexPath.row])
        cell.issueDelegate = self
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        output.didSelectViewModel(sections[indexPath.section].cellViewModels[indexPath.row])
    }
}

extension ChainAssetListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].cellViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(ChainAccountBalanceTableCell.self) else {
            return UITableViewCell()
        }
        cell.delegate = self

        return cell
    }
}

extension ChainAssetListViewController: SwipableTableViewCellDelegate {
    func swipeCellDidTap(on actionType: SwipableCellButtonType, with indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            return
        }
        let viewModelForAction = sections[indexPath.section].cellViewModels[indexPath.row]
        output.didTapAction(actionType: actionType, viewModel: viewModelForAction)
    }
}

extension ChainAssetListViewController: ChainAccountBalanceTableCellDelegate {
    func issueButtonTapped(with indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            return
        }

        let viewModel = sections[indexPath.section].cellViewModels[indexPath.row]
        output.didTapOnIssueButton(viewModel: viewModel)
    }
}
