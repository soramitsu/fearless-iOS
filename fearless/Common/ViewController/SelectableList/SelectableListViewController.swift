import UIKit
import SoraFoundation

class SelectableListViewController<C: UITableViewCell & SelectionItemViewProtocol>:
    UIViewController,
    UITableViewDataSource,
    UITableViewDelegate,
    ViewHolder {
    typealias RootViewType = SelectableListViewLayout

    // MARK: Private properties

    private let listPresenter: SelectionListPresenterProtocol

    // MARK: - Constructor

    init(listPresenter: SelectionListPresenterProtocol) {
        self.listPresenter = listPresenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = SelectableListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
    }

    // MARK: - Private methods

    private func configureTableView() {
        rootView.tableView.registerClassForCell(C.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.allowsSelection = true
    }

    // MARK: - UITableView DataSource

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        listPresenter.numberOfItems
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(C.self) else {
            return UITableViewCell()
        }
        return cell
    }

    // MARK: - UITableView Delegate

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? C else {
            return
        }
        let viewModel = listPresenter.item(at: indexPath.row)
        cell.bind(viewModel: viewModel)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        listPresenter.selectItem(at: indexPath.row)
    }
}

// MARK: - SelectionListViewProtocol

extension SelectableListViewController: SelectionListViewProtocol {
    func didReload() {
        rootView.tableView.reloadData()
    }
}
