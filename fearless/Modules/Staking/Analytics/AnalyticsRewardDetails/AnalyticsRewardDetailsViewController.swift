import UIKit
import SoraFoundation

final class AnalyticsRewardDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AnalyticsRewardDetailsViewLayout

    let presenter: AnalyticsRewardDetailsPresenterProtocol
    let localizationManager: LocalizationManagerProtocol?

    init(
        presenter: AnalyticsRewardDetailsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol? = nil
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsRewardDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        presenter.setup()
    }
}

extension AnalyticsRewardDetailsViewController: AnalyticsRewardDetailsViewProtocol {
    func bind(viewModel: LocalizableResource<AnalyticsRewardDetailsViewModel>) {
        let localizedViewModel = viewModel.value(for: selectedLocale)
        rootView.blockNumberView.subtitle = localizedViewModel.blockNumber
        rootView.dateView.valueLabel.text = localizedViewModel.date
        rootView.typeView.valueLabel.text = localizedViewModel.type
        rootView.amountView.valueLabel.text = localizedViewModel.amount
    }
}

extension AnalyticsRewardDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = "Details" // TODO:
            rootView.locale = selectedLocale
        }
    }
}
