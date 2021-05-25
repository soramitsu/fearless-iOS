import UIKit

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

        presenter.setup()
        rootView.segmentedControl.configure()
        rootView.segmentedControl.titles = ["Rewards", "Stake", "Validators"]

        rootView.periodView.configure(periods: AnalyticsPeriod.allCases)
        rootView.periodView.delegate = self
    }
}

extension AnalyticsViewController: AnalyticsViewProtocol {}

extension AnalyticsViewController: AnalyticsPeriodViewDelegate {
    func didSelect(period: AnalyticsPeriod) {
        print(period)
    }
}
