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

        applyLocalization()

        rootView.actionsWidget.delegate = self
        rootView.unbondingWidget.moreButton.addTarget(
            self,
            action: #selector(handleUnbondingMoreButton),
            for: .touchUpInside
        )

        setupNavigationBarStyle()
        presenter.setup()
    }

    private func setupNavigationBarStyle() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        let navBarHeight = navigationBar.bounds.height
        let blurHeight = statusBarHeight + navBarHeight
        rootView.navBarBlurViewHeightConstraint.update(offset: blurHeight)
    }

    @objc
    private func handleUnbondingMoreButton() {
        presenter.handleUnbondingMoreAction()
    }
}

extension StakingBalanceViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable.stakingBalanceTitle(preferredLanguages: selectedLocale.rLanguages)
        }
    }
}

extension StakingBalanceViewController: StakingBalanceViewProtocol {
    func reload(with viewModel: LocalizableResource<StakingBalanceViewModel>) {
        let localizedViewModel = viewModel.value(for: selectedLocale)

        rootView.balanceWidget.bind(viewModel: localizedViewModel.widgetViewModel)
        rootView.actionsWidget.bind(viewModel: localizedViewModel.actionsViewModel)
        rootView.unbondingWidget.bind(viewModel: localizedViewModel.unbondingViewModel)
    }
}

extension StakingBalanceViewController: StakingBalanceActionsWidgetViewDelegate {
    func didSelect(action: StakingBalanceAction) {
        presenter.handleAction(action)
    }
}
