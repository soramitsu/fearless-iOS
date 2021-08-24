import UIKit
import SoraFoundation
import SoraUI

protocol AnalyticsRewardsPresenterBaseProtocol: AnyObject {
    func setup()
    func reload()
    func didSelectPeriod(_ period: AnalyticsPeriod)
    func didSelectPrevious()
    func didSelectNext()
    func handleReward(atIndex index: Int)
}

protocol AnalyticsRewardsBaseViewModel {
    var rewardSections: [AnalyticsRewardSection] { get }
    var locale: Locale { get }
    var isEmpty: Bool { get }
}

class AnalyticsRewardsBaseViewController<
    VM: AnalyticsRewardsBaseViewModel,
    Header: UIView,
    Presenter: AnalyticsRewardsPresenterBaseProtocol
>: UIViewController,
    ViewHolder,
    UITableViewDataSource,
    UITableViewDelegate {
    typealias RootViewType = AnalyticsRewardsBaseView<Header>

    let presenter: Presenter

    var viewState: AnalyticsViewState<VM>?

    init(presenter: Presenter) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = RootViewType()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        setupPeriodView()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.registerClassForCell(AnalyticsHistoryCell.self)
        rootView.tableView.registerClassForCell(EmptyStateViewCell.self)
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

    // MARK: - UITableViewDataSource

    func numberOfSections(in _: UITableView) -> Int {
        guard case let .loaded(viewModel) = viewState else { return 0 }
        guard !viewModel.isEmpty else { return 1 }
        return viewModel.rewardSections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = viewState else { return 0 }
        guard !viewModel.isEmpty else { return 1 }
        return viewModel.rewardSections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(AnalyticsHistoryCell.self, forIndexPath: indexPath)
        guard case let .loaded(viewModel) = viewState else {
            return cell
        }
        guard !viewModel.isEmpty else {
            let emptyCell = tableView.dequeueReusableCellWithType(EmptyStateViewCell.self)!
            setupEmptyView(emptyCell.emptyView, locale: viewModel.locale)
            return emptyCell
        }
        let cellViewModel = viewModel.rewardSections[indexPath.section].items[indexPath.row]
        cell.historyView.bind(model: cellViewModel)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .loaded(viewModel) = viewState, !viewModel.isEmpty else { return nil }
        let header: AnalyticsSectionHeader = tableView.dequeueReusableHeaderFooterView()
        header.label.text = viewModel.rewardSections[section].title
        return header
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(viewModel) = viewState else {
            return
        }

        presenter.handleReward(atIndex: indexPath.row)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard
            case let .loaded(viewModel) = viewState,
            viewModel.isEmpty
        else { return UITableView.automaticDimension }
        return 0
    }

    private func setupEmptyView(_ emptyView: EmptyStateView, locale: Locale) {
        emptyView.image = R.image.iconEmptyHistory()
        emptyView.title = R.string.localizable
            .crowdloanEmptyMessage(preferredLanguages: locale.rLanguages)
        emptyView.titleColor = R.color.colorLightGray()!
        emptyView.titleFont = .p2Paragraph
    }
}

extension AnalyticsRewardsBaseViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension AnalyticsRewardsBaseViewController: EmptyStateDataSource {
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

extension AnalyticsRewardsBaseViewController: EmptyStateDelegate {
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

extension AnalyticsRewardsBaseViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.reload()
    }
}

extension AnalyticsRewardsBaseViewController: AnalyticsPeriodViewDelegate {
    func didSelect(period: AnalyticsPeriod) {
        presenter.didSelectPeriod(period)
    }
}

extension AnalyticsRewardsBaseViewController: AnalyticsPeriodSelectorViewDelegate {
    func didSelectNext() {
        presenter.didSelectNext()
    }

    func didSelectPrevious() {
        presenter.didSelectPrevious()
    }
}

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
