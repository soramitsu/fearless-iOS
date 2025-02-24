import UIKit
import SoraFoundation

protocol BridgeListViewOutput: AnyObject {
    func didLoad(view: BridgeListViewInput)
    func didTapBackButton()
    func didTapSaveButton()
    func didSelectBridge(id: String?)
}

final class BridgeListViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    var loadableContentView: UIView {
        rootView.tableView
    }
    
    typealias RootViewType = BridgeListViewLayout

    // MARK: Private properties

    private let output: BridgeListViewOutput
    private var viewModels: [BridgeListTableCellModel]?

    // MARK: - Constructor

    init(
        output: BridgeListViewOutput,
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
        view = BridgeListViewLayout()
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
        rootView.tableView.registerClassForCell(BridgeListTableCell.self)
        rootView.tableView.backgroundColor = R.color.colorBlack()!
        rootView.tableView.separatorStyle = .none
    }
}

// MARK: - BridgeListViewInput

extension BridgeListViewController: BridgeListViewInput {
    func didReceive(viewModel: BridgeListViewModel) {
        rootView.navigationBar.setTitle(viewModel.title)

        viewModels = viewModel.cellModels
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension BridgeListViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension BridgeListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        (viewModels?.count).or(0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(BridgeListTableCell.self, forIndexPath: indexPath)
        let viewModel = viewModels?[indexPath.row]
        cell.bind(viewModel: viewModel)
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = viewModels?[indexPath.row] else {
            return
        }

        output.didSelectBridge(id: viewModel.bridgeId)
    }
}
