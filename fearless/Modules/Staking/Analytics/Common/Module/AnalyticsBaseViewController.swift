import UIKit
import SoraFoundation
import SoraUI

class AnalyticsRewardsBaseViewController<
    VM: AnalyticsBaseViewModel,
    Header: AnalyticsRewardsHeaderViewProtocol,
    Presenter: AnalyticsPresenterBaseProtocol
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
        rootView.headerView.periodView.delegate = self
    }

    @objc
    private func refreshControlDidTriggered() {
        presenter.reload()
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in _: UITableView) -> Int {
        guard case let .loaded(viewModel) = viewState else { return 0 }
        guard !viewModel.isEmpty else { return 1 }
        return viewModel.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .loaded(viewModel) = viewState else { return 0 }
        guard !viewModel.isEmpty else { return 1 }
        return viewModel.sections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(AnalyticsHistoryCell.self, forIndexPath: indexPath)
        guard case let .loaded(viewModel) = viewState else {
            return cell
        }
        guard !viewModel.isEmpty else {
            let emptyCell = tableView.dequeueReusableCellWithType(EmptyStateViewCell.self)!
            setupEmptyView(emptyCell.emptyView, title: viewModel.emptyListDescription)
            return emptyCell
        }
        let cellItem = viewModel.sections[indexPath.section].items[indexPath.row]
        cell.historyView.bind(model: cellItem.viewModel)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case let .loaded(viewModel) = viewState, !viewModel.isEmpty else { return nil }
        let header: AnalyticsSectionHeader = tableView.dequeueReusableHeaderFooterView()
        header.label.text = viewModel.sections[section].title
        return header
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .loaded(viewModel) = viewState else {
            return
        }

        let rawModel = viewModel.sections[indexPath.section].items[indexPath.row].rawModel
        presenter.handleReward(rawModel)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard
            case let .loaded(viewModel) = viewState,
            viewModel.isEmpty
        else { return UITableView.automaticDimension }
        return 0
    }

    private func setupEmptyView(_ emptyView: EmptyStateView, title: String) {
        emptyView.image = R.image.iconEmptyHistory()
        emptyView.title = title
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
