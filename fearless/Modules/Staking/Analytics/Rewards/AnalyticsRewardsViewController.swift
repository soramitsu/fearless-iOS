import UIKit
import SoraFoundation

final class AnalyticsRewardsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsRewardsView

    private let presenter: AnalyticsRewardsPresenterProtocol

    private var viewState: AnalyticsViewState<AnalyticsRewardsViewModel> = .loading(false)

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
        rootView.tableView.dataSource = self
    }

    private func setupPeriodView() {
        rootView.periodSelectorView.periodView.delegate = self
        rootView.periodSelectorView.delegate = self
    }
}

extension AnalyticsRewardsViewController: AnalyticsRewardsViewProtocol {
    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { _ in
            "Rewards"
        }
    }

    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>) {
        self.viewState = viewState
        switch viewState {
        case let .loading(isLoading):
            rootView.periodSelectorView.isHidden = true
        case let .success(viewModel):
            rootView.periodSelectorView.isHidden = false
            rootView.periodSelectorView.bind(viewModel: viewModel.periodViewModel)

            rootView.tableView.reloadData()
        case let .error(error):
            rootView.periodSelectorView.isHidden = true
            print(error.localizedDescription)
        }
    }
}

extension AnalyticsRewardsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard case let .success(viewModel) = viewState else { return 0 }
        return viewModel.rewardSections[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(AnalyticsHistoryCell.self, forIndexPath: indexPath)
        guard case let .success(viewModel) = viewState else {
            return cell
        }
        let cellViewModel = viewModel.rewardSections[indexPath.section].items[indexPath.row]
        cell.historyView.bind(model: cellViewModel)
        return cell
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
