import UIKit

final class ChainAccountBalanceListViewController: UIViewController {
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

        presenter.setup()
    }

    private func applyState(_: ChainAccountBalanceListViewState) {}
}

extension ChainAccountBalanceListViewController: ChainAccountBalanceListViewProtocol {
    func didReceive(state: ChainAccountBalanceListViewState) {
        self.state = state

        applyState(state)
    }
}

extension ChainAccountBalanceListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard chainInfo != nil else {
            return 0
        }

        switch state {
        case let .loaded(viewModel):
            if viewModel.active != nil, viewModel.completed != nil {
                return 3
            } else if viewModel.active != nil || viewModel.completed != nil {
                return 2
            } else {
                return 1
            }
        case .loading, .empty, .error:
            return 1
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = state else {
            return 0
        }
        
        return viewModel.accountViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard case let .loaded(viewModel) = state else {
            return UITableViewCell()
        }

        if indexPath.section == 1, let active = viewModel.active {
            return createActiveTableViewCell(
                tableView,
                viewModel: active.crowdloans[indexPath.row].content
            )
        }

        if let completed = viewModel.completed {
            return createCompletedTableViewCell(
                tableView,
                viewModel: completed.crowdloans[indexPath.row].content
            )
        }

        return UITableViewCell()
    }

    private func createActiveTableViewCell(
        _ tableView: UITableView,
        viewModel: ActiveCrowdloanViewModel
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(ActiveCrowdloanTableViewCell.self)!
        cell.bind(viewModel: viewModel)
        return cell
    }

    private func createCompletedTableViewCell(
        _ tableView: UITableView,
        viewModel: CompletedCrowdloanViewModel
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(CompletedCrowdloanTableViewCell.self)!
        cell.bind(viewModel: viewModel)
        return cell
    }
}

extension ChainAccountBalanceListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(viewModel) = state else {
            return
        }

        if indexPath.section == 1, let active = viewModel.active {
            presenter.selectViewModel(active.crowdloans[indexPath.row])
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section > 0, case let .loaded(viewModel) = state else {
            return nil
        }

        let headerView: CrowdloanStatusSectionView = tableView.dequeueReusableHeaderFooterView()

        if section == 1, let active = viewModel.active {
            headerView.bind(title: active.title, status: .active)
        } else if let completed = viewModel.completed {
            headerView.bind(title: completed.title, status: .completed)
        }

        return headerView
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section > 0 ? 40.0 : 0.0
    }
}
