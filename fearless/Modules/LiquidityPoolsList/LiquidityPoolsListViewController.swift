import UIKit
import SoraFoundation

final class LiquidityPoolsListViewController: UIViewController, ViewHolder {
    typealias RootViewType = LiquidityPoolsListViewLayout

    // MARK: Private properties

    private var cellModels: [LiquidityPoolListCellModel] = []
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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cellModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCellWithType(LiquidityPoolListCell.self) ?? UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let lpCell = cell as? LiquidityPoolListCell else {
            return
        }
        
        lpCell.bind(viewModel: cellModels[indexPath.row])
    }
}

// MARK: - LiquidityPoolsListViewInput

extension LiquidityPoolsListViewController: LiquidityPoolsListViewInput {
    func bind(viewModel: LiquidityPoolListViewModel) {
        cellModels = viewModel.poolViewModels
        
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension LiquidityPoolsListViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
