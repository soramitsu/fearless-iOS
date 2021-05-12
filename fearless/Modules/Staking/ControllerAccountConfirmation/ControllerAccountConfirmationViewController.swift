import UIKit
import SoraFoundation

final class ControllerAccountConfirmationVC: UIViewController, ViewHolder {
    typealias RootViewType = ControllerAccountConfirmationLayout

    let presenter: ControllerAccountConfirmationPresenterProtocol

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
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.commonConfirmTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale
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
}

extension ControllerAccountConfirmationVC: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
