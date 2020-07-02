import UIKit
import Rswift

class SelectionListViewController<C: UITableViewCell & SelectionItemViewProtocol>
    : UIViewController, UITableViewDataSource, UITableViewDelegate {

    var listPresenter: SelectionListPresenterProtocol!

    var selectableCellIdentifier: ReuseIdentifier<C>! { return nil }
    var selectableCellNib: UINib? { return nil }

    @IBOutlet private(set) var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
    }

    private func configureTableView() {
        tableView.register(selectableCellNib,
                           forCellReuseIdentifier: selectableCellIdentifier.identifier)

        let footerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: 1.0)))
        tableView.tableFooterView = footerView
    }

    // MARK: UITableView DataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return listPresenter.numberOfItems
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: selectableCellIdentifier,
                                                 for: indexPath)!

        let viewModel = listPresenter.item(at: indexPath.row)
        cell.bind(viewModel: viewModel)

        return cell
    }

    // MARK: UITableView Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        listPresenter.selectItem(at: indexPath.row)
    }
}

extension SelectionListViewController: SelectionListViewProtocol {
    func didReload() {
        tableView.reloadData()
    }
}
