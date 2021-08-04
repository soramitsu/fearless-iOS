import UIKit
import SoraFoundation

final class AnalyticsStakeViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsStakeView

    private let presenter: AnalyticsStakePresenterProtocol

    private var viewState: AnalyticsViewState<AnalyticsRewardsViewModel> = .loading(false)

    init(presenter: AnalyticsStakePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsStakeView()
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
    }

    private func setupPeriodView() {
        rootView.periodSelectorView.periodView.delegate = self
        rootView.periodSelectorView.delegate = self
    }

    @objc
    private func refreshControlDidTriggered() {
        presenter.reload()
    }
}

extension AnalyticsStakeViewController: AnalyticsStakeViewProtocol {
    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { _ in
            "Stake"
        }
    }

    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>) {
        self.viewState = viewState

        switch viewState {
        case let .loading(isLoading):
            rootView.periodSelectorView.isHidden = true
            if !isLoading {
                rootView.tableView.refreshControl?.endRefreshing()
            }
        case let .loaded(viewModel):
            if !viewModel.rewardSections.isEmpty {
                rootView.periodSelectorView.isHidden = false
                rootView.periodSelectorView.bind(viewModel: viewModel.periodViewModel)
                rootView.headerView.bind(summaryViewModel: viewModel.summaryViewModel, chartData: viewModel.chartData)
                rootView.tableView.reloadData()
            }
        case let .error(error):
            rootView.periodSelectorView.isHidden = true
            print(error.localizedDescription)
        }
    }
}

extension AnalyticsStakeViewController: UITableViewDataSource {
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

extension AnalyticsStakeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(viewModel) = viewState else {
            return
        }

        presenter.handleReward(atIndex: indexPath.row)
    }
}

extension AnalyticsStakeViewController: AnalyticsPeriodViewDelegate {
    func didSelect(period: AnalyticsPeriod) {
        presenter.didSelectPeriod(period)
    }
}

extension AnalyticsStakeViewController: AnalyticsPeriodSelectorViewDelegate {
    func didSelectNext() {
        presenter.didSelectNext()
    }

    func didSelectPrevious() {
        presenter.didSelectPrevious()
    }
}
