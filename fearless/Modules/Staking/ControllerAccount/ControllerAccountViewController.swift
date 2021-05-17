import UIKit
import SoraFoundation

final class ControllerAccountViewController: UIViewController, ViewHolder {
    typealias RootViewType = ControllerAccountViewLayout

    let presenter: ControllerAccountPresenterProtocol

    init(
        presenter: ControllerAccountPresenterProtocol,
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

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    override func loadView() {
        view = ControllerAccountViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        setupActions()
        presenter.setup()
    }

    private func setupActions() {
        rootView.actionButton.addTarget(self, action: #selector(handleActionButton), for: .touchUpInside)
        rootView.learnMoreView.addTarget(self, action: #selector(handleLearnMoreAction), for: .touchUpInside)
        rootView.stashAccountView.addTarget(self, action: #selector(handleStashAction), for: .touchUpInside)
        rootView.controllerAccountView.addTarget(self, action: #selector(handleControllerAction), for: .touchUpInside)
    }

    @objc
    private func handleActionButton() {
        presenter.proceed()
    }

    @objc
    private func handleLearnMoreAction() {
        presenter.selectLearnMore()
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

extension ControllerAccountViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .stakingControllerAccountTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.locale = selectedLocale
        }
    }
}

extension ControllerAccountViewController: ControllerAccountViewProtocol {
    func reload(with viewModel: ControllerAccountViewModel) {
        let stashViewModel = viewModel.stashViewModel.value(for: selectedLocale)
        rootView.stashAccountView.title = stashViewModel.title
        rootView.stashAccountView.subtitle = stashViewModel.name
        rootView.stashAccountView.iconImage = stashViewModel.icon

        let controllerModel = viewModel.controllerViewModel.value(for: selectedLocale)
        rootView.controllerAccountView.title = controllerModel.title
        rootView.controllerAccountView.subtitle = controllerModel.name
        rootView.controllerAccountView.iconImage = controllerModel.icon

        rootView.actionButton.isEnabled = viewModel.actionButtonIsEnabled
        rootView.currentAccountIsControllerHint.isHidden = !viewModel.currentAccountIsController

        let actionImage = viewModel.canChooseOtherController ? R.image.iconSmallArrowDown() : R.image.iconMore()
        rootView.controllerAccountView.actionImage = actionImage
    }
}
