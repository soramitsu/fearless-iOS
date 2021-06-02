import UIKit
import SoraFoundation

final class AnalyticsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsViewLayout

    let presenter: AnalyticsPresenterProtocol

    init(presenter: AnalyticsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Analytics"
        presenter.setup()
        rootView.segmentedControl.configure()
        rootView.segmentedControl.titles = ["Rewards", "Stake", "Validators"]

        rootView.rewardsView.periodView.configure(periods: AnalyticsPeriod.allCases)
        rootView.rewardsView.periodView.delegate = self

        rootView.rewardsView.payoutButton.imageWithTitleView?.title = "Payout rewards"
    }
}

extension AnalyticsViewController: AnalyticsViewProtocol {
    func configure(with viewModel: LocalizableResource<AnalyticsViewModel>) {
        let viewModel = viewModel.value(for: selectedLocale)
        rootView.rewardsView.chartView.setChartData(viewModel.chartData)
        rootView.rewardsView.receivedSummaryView.configure(with: viewModel.receivedViewModel)
        rootView.rewardsView.payableSummaryView.configure(with: viewModel.payableViewModel)
    }
}

extension AnalyticsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            // TODO:
        }
    }
}

extension AnalyticsViewController: AnalyticsPeriodViewDelegate {
    func didSelect(period: AnalyticsPeriod) {
        presenter.didSelectPeriod(period)
    }
}
