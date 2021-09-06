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
        rootView.headerView.chartView.chartDelegate = self
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
        rootView.tableView.nsuiIsScrollEnabled = true

        switch viewState {
        case .loading:
            if let refreshControl = rootView.tableView.refreshControl, !refreshControl.isRefreshing {
                refreshControl.programaticallyBeginRefreshing(in: rootView.tableView)
            }
        case let .loaded(viewModel):
            rootView.tableView.refreshControl?.endRefreshing()
            rootView.headerView.bind(
                summaryViewModel: viewModel.summaryViewModel,
                chartData: viewModel.chartData,
                selectedPeriod: viewModel.selectedPeriod
            )
            rootView.tableView.reloadData()
        case .error:
            rootView.tableView.refreshControl?.endRefreshing()
        }
        reloadEmptyState(animated: true)
    }
}

extension AnalyticsRewardsViewController: FWChartViewDelegate {
    func didSelectXValue(_ value: Double) {
        rootView.tableView.nsuiIsScrollEnabled = false
        presenter.didSelectXValue(Int(value))
    }

    func didUnselect() {
        rootView.tableView.nsuiIsScrollEnabled = true
        presenter.didUnselectXValue()
    }
}
