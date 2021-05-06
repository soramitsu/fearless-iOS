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

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleLearnMoreAction))
        rootView.learnMoreView.addGestureRecognizer(tapRecognizer)

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
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable
                .commonContinue(preferredLanguages: selectedLocale.rLanguages)
            rootView.learnMoreView.titleLabel.text = R.string.localizable
                .commonLearnMore(preferredLanguages: selectedLocale.rLanguages)
            rootView.hintView.titleLabel.text = R.string.localizable
                .stakingCurrentAccountIsController(preferredLanguages: selectedLocale.rLanguages)
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

        switch viewModel.actionButtonState {
        case let .enabled(isEnabled):
            rootView.actionButton.isEnabled = isEnabled
            rootView.actionButton.isHidden = false
            rootView.hintView.isHidden = true
        case .hidden:
            rootView.actionButton.isHidden = true
            rootView.hintView.isHidden = false
        }

        let actionImage = viewModel.canChooseOtherController ? R.image.iconSmallArrowDown() : R.image.iconMore()
        rootView.controllerAccountView.actionImage = actionImage
    }
}
