import UIKit
import SoraFoundation

final class ChainAccountBalanceListViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChainAccountBalanceListViewLayout

    let presenter: ChainAccountBalanceListPresenterProtocol

    private var state: ChainAccountBalanceListViewState = .loading

    init(presenter: ChainAccountBalanceListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChainAccountBalanceListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        presenter.setup()
    }

    func configure() {
        rootView.tableView.registerClassForCell(ChainAccountBalanceTableCell.self)

        rootView.tableView.tableFooterView = UIView()

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(
                self,
                action: #selector(pullToRefreshOnAssetsTableHandler),
                for: .valueChanged
            )
        }
    }

    @objc private func pullToRefreshOnAssetsTableHandler() {
        presenter.didPullToRefreshOnAssetsTable()
    }

    private func applyState(_ state: ChainAccountBalanceListViewState) {
        switch state {
        case .loading:
            rootView.tableView.isHidden = true
        case let .loaded(viewModel):
            rootView.tableView.isHidden = false
            rootView.tableView.reloadData()

            rootView.bind(to: viewModel)
        }
    }
}

extension ChainAccountBalanceListViewController: ChainAccountBalanceListViewProtocol {
    func didReceive(state: ChainAccountBalanceListViewState) {
        rootView.tableView.refreshControl?.endRefreshing()

        self.state = state

        applyState(state)
    }
}

extension ChainAccountBalanceListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard case .loaded = state else {
            return 0
        }

        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }

        return viewModel.accountViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCellWithType(ChainAccountBalanceTableCell.self)!
        cell.bind(to: viewModel.accountViewModels[indexPath.row])
        return cell
    }
}

extension ChainAccountBalanceListViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard case let .loaded(viewModel) = state else {
            return
        }

        presenter.didSelectViewModel(viewModel.accountViewModels[indexPath.row])
    }
}

extension ChainAccountBalanceListViewController: Localizable {
    func applyLocalization() {}
}

extension ChainAccountBalanceListViewController: HiddableBarWhenPushed {}
