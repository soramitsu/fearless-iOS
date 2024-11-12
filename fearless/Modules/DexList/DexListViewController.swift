import UIKit
import SoraFoundation

protocol DexListViewOutput: AnyObject {
    func didLoad(view: DexListViewInput)
    func didTapBackButton()
    func didTapSaveButton()
    func didSelectLiquiditySource(with id: String)
}

final class DexListViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = DexListViewLayout

    // MARK: Private properties

    private let output: DexListViewOutput
    private var viewModels: [DexListTableCellModel]?

    // MARK: - Constructor

    init(
        output: DexListViewOutput,
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
        view = DexListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        setupTableView()

        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didTapBackButton()
        }

        rootView.saveButton.addAction { [weak self] in
            self?.output.didTapSaveButton()
        }
    }

    // MARK: - Private methods

    private func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(DexListTableCell.self)
        rootView.tableView.backgroundColor = R.color.colorBlack()!
        rootView.tableView.separatorStyle = .none
    }
}

// MARK: - DexListViewInput

extension DexListViewController: DexListViewInput {
    func didReceive(viewModel: DexListViewModel) {
        rootView.navigationBar.setTitle(viewModel.title)

        viewModels = viewModel.cellModels
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension DexListViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension DexListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        (viewModels?.count).or(0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(DexListTableCell.self, forIndexPath: indexPath)
        let viewModel = viewModels?[indexPath.row]
        cell.bind(viewModel: viewModel)
        return cell
    }

    func tableView(_: UITableView, willDisplay _: UITableViewCell, forRowAt _: IndexPath) {
//        if let dexListCell = cell as? DexListTableCell {
//            let viewModel = viewModels?[indexPath.row]
//            dexListCell.bind(viewModel: viewModel)
//        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = viewModels?[indexPath.row] else {
            return
        }

        output.didSelectLiquiditySource(with: viewModel.dexId)
    }
}
