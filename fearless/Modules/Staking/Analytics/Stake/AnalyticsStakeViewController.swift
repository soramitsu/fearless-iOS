import UIKit
import SoraFoundation
import SoraUI

final class AnalyticsStakeViewController:
    AnalyticsRewardsBaseViewController<
        AnalyticsRewardsViewModel,
        AnalyticsStakeHeaderView,
        AnalyticsStakePresenter
    >, AnalyticsStakeViewProtocol {
    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingStake(preferredLanguages: locale.rLanguages)
        }
    }

    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>) {
        self.viewState = viewState

        switch viewState {
        case .loading:
            if let refreshControl = rootView.tableView.refreshControl, !refreshControl.isRefreshing {
                refreshControl.programaticallyBeginRefreshing(in: rootView.tableView)
                rootView.periodSelectorView.isHidden = true
            }
        case let .loaded(viewModel):
            rootView.tableView.refreshControl?.endRefreshing()
            rootView.periodSelectorView.isHidden = false
            rootView.periodSelectorView.bind(viewModel: viewModel.periodViewModel)
            rootView.headerView.bind(summaryViewModel: viewModel.summaryViewModel, chartData: viewModel.chartData)
            rootView.tableView.reloadData()
        case .error:
            rootView.tableView.refreshControl?.endRefreshing()
            rootView.periodSelectorView.isHidden = true
        }
        reloadEmptyState(animated: true)
    }
}
