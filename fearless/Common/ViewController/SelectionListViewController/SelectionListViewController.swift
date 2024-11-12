import UIKit
import Rswift
import SoraUI
import SoraFoundation

class SelectionListViewController<C: UITableViewCell & SelectionItemViewProtocol>:
    UIViewController,
    UITableViewDataSource,
    UITableViewDelegate,
    EmptyStateDelegate,
    EmptyStateDataSource,
    EmptyStateViewOwnerProtocol,
    Localizable
{
    func applyLocalization() {
        reloadEmptyState(animated: true)
    }

    var shouldDisplayEmptyState: Bool { errorMessage != nil }

    var viewForEmptyState: UIView? {
        let emptyView = EmptyView()
        emptyView.image = R.image.iconWarning()
        emptyView.title = R.string.localizable
            .emptyViewTitle(preferredLanguages: selectedLocale.rLanguages)
        emptyView.text = errorMessage
        emptyView.iconMode = .bigFilledShadow
        emptyView.retryButton.setTitle(R.string.localizable.commonRetry(preferredLanguages: selectedLocale.rLanguages), for: .normal)
        emptyView.retryButton.isHidden = false
        emptyView.retryButton.addAction { [weak self] in
            self?.listPresenter.didTapRetry()
        }
        return emptyView
    }

    var emptyStateDelegate: SoraUI.EmptyStateDelegate {
        self
    }

    var emptyStateDataSource: SoraUI.EmptyStateDataSource {
        self
    }

    var listPresenter: SelectionListPresenterProtocol!

    var selectableCellIdentifier: ReuseIdentifier<C>! { nil }
    var selectableCellNib: UINib? { nil }

    @IBOutlet private(set) var tableView: UITableView!

    private var errorMessage: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
    }

    private func configureTableView() {
        if let nib = selectableCellNib {
            tableView.register(
                nib,
                forCellReuseIdentifier: selectableCellIdentifier.identifier
            )
        } else {
            tableView.register(
                C.self,
                forCellReuseIdentifier: selectableCellIdentifier.identifier
            )
        }

        let footerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: 1.0)))
        tableView.tableFooterView = footerView
    }

    // MARK: UITableView DataSource

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        listPresenter.numberOfItems
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: selectableCellIdentifier,
            for: indexPath
        )!

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
    func didReceive(errorMessage: String?) {
        self.errorMessage = errorMessage
        reloadEmptyState(animated: true)
    }

    func didReload() {
        tableView.reloadData()
        reloadEmptyState(animated: true)
    }

    func bind(viewModel _: TextSearchViewModel?) {}
}
