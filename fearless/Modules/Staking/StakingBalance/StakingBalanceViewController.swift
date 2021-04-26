import UIKit
import SoraFoundation

final class StakingBalanceViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingBalanceViewLayout

    let presenter: StakingBalancePresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: StakingBalancePresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
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
        view = StakingBalanceViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTitle()
        presenter.setup()
    }

    private func setupTitle() {
        title = R.string.localizable.stakingBalanceTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension StakingBalanceViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupTitle()
            rootView.unbondingWidget.titleLabel.text = R.string.localizable
                .walletBalanceUnbonding(preferredLanguages: selectedLocale.rLanguages)
        }
    }
}

extension StakingBalanceViewController: StakingBalanceViewProtocol {
    func reload(with viewModel: LocalizableResource<StakingBalanceViewModel>) {
        let localizedViewModel = viewModel.value(for: selectedLocale)

        rootView.balanceWidget.bind(viewModels: localizedViewModel.widgetViewModels)
    }
}
