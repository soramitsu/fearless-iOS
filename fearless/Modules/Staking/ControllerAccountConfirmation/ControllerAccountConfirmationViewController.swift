import UIKit
import SoraFoundation

final class ControllerAccountConfirmationVC: UIViewController, ViewHolder {
    typealias RootViewType = ControllerAccountConfirmationLayout

    let presenter: ControllerAccountConfirmationPresenterProtocol
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: ControllerAccountConfirmationPresenterProtocol,
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
        view = ControllerAccountConfirmationLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupActions()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.commonConfirmTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale
        applyFeeViewModel()
    }

    private func applyFeeViewModel() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeConfirmView.networkFeeView.bind(viewModel: viewModel)
    }

    private func setupActions() {
        rootView.networkFeeConfirmView
            .actionButton.addTarget(self, action: #selector(handleActionButton), for: .touchUpInside)
        rootView.stashAccountView.addTarget(self, action: #selector(handleStashAction), for: .touchUpInside)
        rootView.controllerAccountView.addTarget(self, action: #selector(handleControllerAction), for: .touchUpInside)
    }

    @objc
    private func handleActionButton() {
        presenter.confirm()
    }

    @objc
    private func handleStashAction() {
        presenter.handleStashAction()
    }

    @objc
    private func handleControllerAction() {
        presenter.handleControllerAction()
    }
}

extension ControllerAccountConfirmationVC: ControllerAccountConfirmationViewProtocol {
    func reload(with viewModel: LocalizableResource<ControllerAccountConfirmationVM>) {
        let localizedViewModel = viewModel.value(for: selectedLocale)

        let stashViewModel = localizedViewModel.stashViewModel
        rootView.stashAccountView.title = stashViewModel.title
        rootView.stashAccountView.subtitle = stashViewModel.name
        rootView.stashAccountView.iconImage = stashViewModel.icon

        let controllerModel = localizedViewModel.controllerViewModel
        rootView.controllerAccountView.title = controllerModel.title
        rootView.controllerAccountView.subtitle = controllerModel.name
        rootView.controllerAccountView.iconImage = controllerModel.icon
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        feeViewModel = viewModel
        applyFeeViewModel()
    }
}

extension ControllerAccountConfirmationVC: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
