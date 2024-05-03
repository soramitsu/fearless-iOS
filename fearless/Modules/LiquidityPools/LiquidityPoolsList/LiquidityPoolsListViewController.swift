import UIKit
import SoraFoundation

final class LiquidityPoolsListViewController: UIViewController, ViewHolder {
    typealias RootViewType = LiquidityPoolsListViewLayout

    // MARK: Private properties

    private var cellModels: [LiquidityPoolListCellModel]?
    private let output: LiquidityPoolsListViewOutput

    // MARK: - Constructor

    init(
        output: LiquidityPoolsListViewOutput,
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
        view = LiquidityPoolsListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(LiquidityPoolListCell.self)
    }

    // MARK: - Private methods
}

extension LiquidityPoolsListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard let cellModels else {
            return 0
        }

        return cellModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        tableView.dequeueReusableCellWithType(LiquidityPoolListCell.self) ?? UITableViewCell()
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let lpCell = cell as? LiquidityPoolListCell, let cellModels else {
            return
        }

        lpCell.bind(viewModel: cellModels[indexPath.row])
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - LiquidityPoolsListViewInput

extension LiquidityPoolsListViewController: LiquidityPoolsListViewInput {
    func didReceive(viewModel: LiquidityPoolListViewModel) {
        cellModels = viewModel.poolViewModels
        rootView.bind(viewModel: viewModel)

        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension LiquidityPoolsListViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
