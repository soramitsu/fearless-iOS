import UIKit
import SoraFoundation
import SoraUI

final class AnalyticsRewardsViewController:
    AnalyticsRewardsBaseViewController<
        AnalyticsRewardsViewModel,
        AnalyticsRewardsHeaderView,
        AnalyticsRewardsPresenter
    > {
    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.headerView.pendingRewardsView.addTarget(
            self,
            action: #selector(handlePengingRewards),
            for: .touchUpInside
        )
    }

    @objc
    private func handlePengingRewards() {
        presenter.handlePendingRewardsAction()
    }
}

extension AnalyticsRewardsViewController: AnalyticsRewardsViewProtocol {
    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingRewardsTitle(preferredLanguages: locale.rLanguages)
        }
    }

    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>) {
        self.viewState = viewState

        switch viewState {
        case .loading:
            if let refreshControl = rootView.tableView.refreshControl, !refreshControl.isRefreshing {
                refreshControl.programaticallyBeginRefreshing(in: rootView.tableView)
            }
        case let .loaded(viewModel):
            rootView.tableView.refreshControl?.endRefreshing()
            rootView.headerView.bind(summaryViewModel: viewModel.summaryViewModel, chartData: viewModel.chartData)
            rootView.tableView.reloadData()
        case .error:
            rootView.tableView.refreshControl?.endRefreshing()
        }
        reloadEmptyState(animated: true)
    }
}
