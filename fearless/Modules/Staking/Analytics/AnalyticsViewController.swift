import UIKit
import SoraFoundation

final class AnalyticsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsViewLayout

    let presenter: AnalyticsPresenterProtocol
    let stakeView: AnalyticsStakeViewProtocol?

    init(
        presenter: AnalyticsPresenterProtocol,
        stakeView: AnalyticsStakeViewProtocol?,
        localizationManager: LocalizationManager? = nil
    ) {
        self.presenter = presenter
        self.stakeView = stakeView
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
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
        rootView.segmentedControl.titles = ["Rewards", "Stake"]
        rootView.segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        rootView.horizontalScrollView.delegate = self
        rootView.rewardsView.periodSelectorView.periodView.delegate = self
        rootView.rewardsView.periodSelectorView.delegate = self

        rootView.rewardsView.payoutButton.imageWithTitleView?.title = "Payout rewards"

        setupStakeView()
    }

    @objc
    private func segmentedControlChanged() {
        let selectedSegmentIndex = rootView.segmentedControl.selectedSegmentIndex
        rootView.horizontalScrollView.scrollTo(horizontalPage: selectedSegmentIndex, animated: true)
    }

    private func setupStakeView() {
        guard let controller = stakeView?.controller else { return }
        addChild(controller)
        let view = controller.view!
        rootView.stakeContainerView.addSubview(view)
        view.snp.makeConstraints { $0.edges.equalToSuperview() }
        controller.didMove(toParent: self)
    }
}

extension AnalyticsViewController: AnalyticsViewProtocol {
    func configureRewards(viewModel: LocalizableResource<AnalyticsRewardsViewModel>) {
        let viewModel = viewModel.value(for: selectedLocale)
        rootView.rewardsView.bind(viewModel: viewModel)
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

extension AnalyticsViewController: AnalyticsPeriodSelectorViewDelegate {
    func didSelectNext() {
        presenter.didSelectNext()
    }

    func didSelectPrevious() {
        presenter.didSelectPrevious()
    }
}

extension AnalyticsViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let indexOfPage = Int(scrollView.contentOffset.x / scrollView.frame.size.width)
        rootView.segmentedControl.selectedSegmentIndex = indexOfPage
    }
}
