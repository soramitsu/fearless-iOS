import UIKit
import SoraFoundation

final class AnalyticsStakeViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsStakeViewLayout

    let presenter: AnalyticsStakePresenterProtocol

    init(
        presenter: AnalyticsStakePresenterProtocol,
        localizationManager: LocalizationManager? = nil
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsStakeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupPeriodView()
        presenter.setup()
    }

    private func setupPeriodView() {
        rootView.periodSelectorView.periodView.delegate = self
        rootView.periodSelectorView.delegate = self
    }
}

extension AnalyticsStakeViewController: AnalyticsStakeViewProtocol {
    func reload(viewModel: LocalizableResource<AnalyticsStakeViewModel>) {
        let localizedViewModel = viewModel.value(for: selectedLocale)
        rootView.bind(viewModel: localizedViewModel)
    }

    var localizedTitle: LocalizableResource<String> {
        LocalizableResource { _ in
            "Stake"
        }
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

extension AnalyticsStakeViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {}
    }
}
