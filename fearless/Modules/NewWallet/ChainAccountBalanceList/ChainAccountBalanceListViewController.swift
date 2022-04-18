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

        rootView.delegate = self

        if let refreshControl = rootView.tableView.refreshControl {
            refreshControl.addTarget(
                self,
                action: #selector(pullToRefreshOnAssetsTableHandler),
                for: .valueChanged
            )
        }

        rootView.manageAssetsButton.addTarget(
            self,
            action: #selector(manageAssetsButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func pullToRefreshOnAssetsTableHandler() {
        presenter.didPullToRefreshOnAssetsTable()
    }

    @objc private func manageAssetsButtonClicked() {
        presenter.didTapManageAssetsButton()
    }

    private func applyState(_ state: ChainAccountBalanceListViewState) {
        switch state {
        case .loading:
            rootView.tableView.isHidden = true
        case let .loaded(viewModel):
            rootView.tableView.isHidden = false
            rootView.tableView.reloadData()
            rootView.bind(to: viewModel)
        case .error:
            rootView.tableView.isHidden = true
        }
    }
}

extension ChainAccountBalanceListViewController: ChainAccountBalanceListViewProtocol {
    func didReceive(state: ChainAccountBalanceListViewState) {
        rootView.tableView.refreshControl?.endRefreshing()

        self.state = state

        applyState(state)
    }

    func didReceive(locale: Locale) {
        rootView.locale = locale
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

        guard let cell = tableView.dequeueReusableCellWithType(ChainAccountBalanceTableCell.self)
        else {
            return UITableViewCell()
        }

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
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension ChainAccountBalanceListViewController: ChainAccountBalanceListViewDelegate {
    func accountButtonDidTap() {
        presenter.didTapAccountButton()
    }
}

extension ChainAccountBalanceListViewController: HiddableBarWhenPushed {}
