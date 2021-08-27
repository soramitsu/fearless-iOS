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
        guard case let .loaded(viewModel) = viewState else {
            return
        }
        let selectedIndex = Int(value)
        let summary = viewModel.chartData.summary[selectedIndex]
        let selectedChartAmounts = viewModel.chartData.amounts.enumerated().map { (index, chartAmount) -> ChartAmount in
            if index == selectedIndex {
                return ChartAmount(value: chartAmount.value, selected: true, filled: true)
            }
            return ChartAmount(value: chartAmount.value, selected: false, filled: false)
        }

        let chartData = viewModel.chartData
        let newChartData = ChartData(
            amounts: selectedChartAmounts,
            summary: chartData.summary,
            xAxisValues: chartData.xAxisValues,
            bottomYValue: chartData.bottomYValue
        )
        rootView.headerView.bind(
            summaryViewModel: summary,
            chartData: newChartData,
            selectedPeriod: viewModel.selectedPeriod
        )
    }

    func didUnselect() {
        guard case let .loaded(viewModel) = viewState else {
            return
        }
        rootView.headerView.bind(
            summaryViewModel: viewModel.summaryViewModel,
            chartData: viewModel.chartData,
            selectedPeriod: viewModel.selectedPeriod
        )
    }
}
