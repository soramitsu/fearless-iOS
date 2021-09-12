import UIKit
import SoraFoundation
import SoraUI

final class AnalyticsValidatorsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsValidatorsView

    let presenter: AnalyticsValidatorsPresenterProtocol

    private var state: AnalyticsViewState<AnalyticsValidatorsViewModel>?

    init(presenter: AnalyticsValidatorsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsValidatorsView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        rootView.headerView.pageSelector.delegate = self
        rootView.headerView.pieChart.chartDelegate = self
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.registerClassForCell(AnalyticsValidatorsCell.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.refreshControl?.addTarget(
            self,
            action: #selector(refreshControlDidTriggered),
            for: .valueChanged
        )
    }

    @objc
    private func refreshControlDidTriggered() {
        presenter.reload()
    }
}

extension AnalyticsValidatorsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard case let .loaded(viewModel) = state else { return 0 }
        return viewModel.validators.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(AnalyticsValidatorsCell.self, forIndexPath: indexPath)
        guard case let .loaded(viewModel) = state else {
            return cell
        }
        let cellViewModel = viewModel.validators[indexPath.row]
        cell.bind(viewModel: cellViewModel)
        cell.delegate = self
        return cell
    }
}

extension AnalyticsValidatorsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        rootView.headerView.pieChart.highlightSegment(index: indexPath.row)
    }
}

extension AnalyticsValidatorsViewController: AnalyticsValidatorsViewProtocol {
    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingRecommendedTitle(preferredLanguages: locale.rLanguages)
        }
    }

    func reload(viewState: AnalyticsViewState<AnalyticsValidatorsViewModel>) {
        state = viewState

        switch viewState {
        case .loading:
            if let refreshControl = rootView.tableView.refreshControl, !refreshControl.isRefreshing {
                refreshControl.programaticallyBeginRefreshing(in: rootView.tableView)
            }
        case let .loaded(viewModel):
            rootView.tableView.refreshControl?.endRefreshing()
            rootView.headerView.pageSelector.bind(selectedPage: viewModel.selectedPage)
            rootView.headerView.pieChart.setAmounts(
                segmentValues: viewModel.pieChartSegmentValues,
                inactiveSegmentValue: viewModel.pieChartInactiveSegment?.percents,
                animated: true
            )
            rootView.headerView.pieChart.setCenterText(viewModel.chartCenterText)
            rootView.headerView.titleLabel.text = viewModel.listTitle
            rootView.tableView.reloadData()
        case .error:
            rootView.tableView.refreshControl?.endRefreshing()
        }
        reloadEmptyState(animated: true)
    }

    func updateChartCenterText(_ text: NSAttributedString) {
        rootView.headerView.pieChart.setCenterText(text)
    }
}

extension AnalyticsValidatorsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension AnalyticsValidatorsViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let state = state else { return nil }

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

extension AnalyticsValidatorsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = state else { return false }
        switch state {
        case .error:
            return true
        case .loading, .loaded:
            return false
        }
    }
}

extension AnalyticsValidatorsViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.reload()
    }
}

extension AnalyticsValidatorsViewController: AnalyticsValidatorsCellDelegate {
    func didTapInfoButton(in cell: AnalyticsValidatorsCell) {
        guard
            let indexPath = rootView.tableView.indexPath(for: cell),
            case let .loaded(viewModel) = state else {
            return
        }
        let cellViewModel = viewModel.validators[indexPath.row]

        presenter.handleValidatorInfoAction(validatorAddress: cellViewModel.validatorAddress)
    }
}

extension AnalyticsValidatorsViewController: AnalyticsValidatorsPageSelectorDelegate {
    func didSelectPage(_ page: AnalyticsValidatorsPage) {
        presenter.handlePageAction(page: page)
    }
}

extension AnalyticsValidatorsViewController: FWPieChartViewDelegate {
    func didSelectSegment(index: Int) {
        guard case let .loaded(viewModel) = state else {
            return
        }
        if index < viewModel.validators.count {
            let selectedValidator = viewModel.validators[index]
            presenter.handleChartSelectedValidator(selectedValidator)
        } else if let inactiveSegment = viewModel.pieChartInactiveSegment {
            presenter.handleChartSelectedInactiveSegment(inactiveSegment)
        }
    }

    func didUnselect() {
        guard case let .loaded(viewModel) = state else {
            return
        }
        rootView.headerView.pieChart.setCenterText(viewModel.chartCenterText)
        rootView.headerView.pieChart.setAmounts(
            segmentValues: viewModel.pieChartSegmentValues,
            inactiveSegmentValue: viewModel.pieChartInactiveSegment?.percents,
            animated: false
        )
    }
}
