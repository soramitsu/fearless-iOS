import UIKit
import SoraFoundation
import SoraUI

final class AnalyticsRewardsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsRewardsView

    private let presenter: AnalyticsRewardsPresenterProtocol

    private var viewState: AnalyticsViewState<AnalyticsRewardsViewModel>?

    init(presenter: AnalyticsRewardsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsRewardsView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        setupPeriodView()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.registerClassForCell(AnalyticsHistoryCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: AnalyticsSectionHeader.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.refreshControl?.addTarget(
            self,
            action: #selector(refreshControlDidTriggered),
            for: .valueChanged
        )
        rootView.headerView.pendingRewardsView.addTarget(
            self,
            action: #selector(handlePengingRewards),
            for: .touchUpInside
        )
    }

    private func setupPeriodView() {
        rootView.periodSelectorView.periodView.delegate = self
        rootView.periodSelectorView.delegate = self
    }

    @objc
    private func refreshControlDidTriggered() {
        presenter.reload()
    }

    @objc
    private func handlePengingRewards() {
        presenter.handlePendingRewardsAction()
    }
}

extension AnalyticsRewardsViewController: AnalyticsRewardsViewProtocol {
    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingAnalyticsReward(preferredLanguages: locale.rLanguages)
        }
    }

    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>) {
        self.viewState = viewState

        switch viewState {
        case .loading:
            if !(rootView.tableView.refreshControl?.isRefreshing ?? true) {
                rootView.periodSelectorView.isHidden = true
                rootView.tableView.refreshControl?.beginRefreshing()
            }
        case let .loaded(viewModel):
            rootView.tableView.refreshControl?.endRefreshing()
            if !viewModel.rewardSections.isEmpty {
                rootView.periodSelectorView.isHidden = false
                rootView.tableView.isHidden = false
                rootView.periodSelectorView.bind(viewModel: viewModel.periodViewModel)
                rootView.headerView.bind(summaryViewModel: viewModel.summaryViewModel, chartData: viewModel.chartData)
                rootView.tableView.reloadData()
            }
        case let .error(error):
            rootView.tableView.refreshControl?.endRefreshing()
            rootView.tableView.isHidden = true
            rootView.periodSelectorView.isHidden = true
        }
        reloadEmptyState(animated: true)
    }
}

extension AnalyticsRewardsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension AnalyticsRewardsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let state = viewState else { return nil }

        switch state {
        case let .error(error):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = error
            errorView.delegate = self
            return errorView
        case .loading, .loaded:
            return nil
        }
    }
}

extension AnalyticsRewardsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = viewState else { return false }
        switch state {
        case .error:
            return true
        case .loading, .loaded:
            return false
        }
    }
}

extension AnalyticsRewardsViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.reload()
    }
}

extension AnalyticsRewardsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard case let .loaded(viewModel) = viewState else { return 0 }
        return viewModel.rewardSections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = viewState else { return 0 }
        return viewModel.rewardSections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(AnalyticsHistoryCell.self, forIndexPath: indexPath)
        guard case let .loaded(viewModel) = viewState else {
            return cell
        }
        let cellViewModel = viewModel.rewardSections[indexPath.section].items[indexPath.row]
        cell.historyView.bind(model: cellViewModel)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .loaded(viewModel) = viewState else { return nil }
        let header: AnalyticsSectionHeader = tableView.dequeueReusableHeaderFooterView()
        header.label.text = viewModel.rewardSections[section].title
        return header
    }
}

extension AnalyticsRewardsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(viewModel) = viewState else {
            return
        }

        presenter.handleReward(atIndex: indexPath.row)
    }
}

extension AnalyticsRewardsViewController: AnalyticsPeriodViewDelegate {
    func didSelect(period: AnalyticsPeriod) {
        presenter.didSelectPeriod(period)
    }
}

extension AnalyticsRewardsViewController: AnalyticsPeriodSelectorViewDelegate {
    func didSelectNext() {
        presenter.didSelectNext()
    }

    func didSelectPrevious() {
        presenter.didSelectPrevious()
    }
}
