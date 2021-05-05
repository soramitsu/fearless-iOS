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
    }

    @objc
    private func handleActionButton() {
        presenter.proceed()
    }

    @objc
    private func handleLearnMoreAction() {
        presenter.selectLearnMore()
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
        }
    }
}

extension ControllerAccountViewController: ControllerAccountViewProtocol {
    func reload(with viewModel: LocalizableResource<ControllerAccountViewModel>) {
        let localizedViewModel = viewModel.value(for: selectedLocale)

        if let stashViewModel = localizedViewModel.stashViewModel {
            rootView.stashAccountView.title = stashViewModel.title
            rootView.stashAccountView.subtitle = stashViewModel.name
            rootView.stashAccountView.iconImage = stashViewModel.icon
        }

        if let controllerModel = localizedViewModel.controllerViewModel {
            rootView.controllerAccountView.title = controllerModel.title
            rootView.controllerAccountView.subtitle = controllerModel.name
            rootView.controllerAccountView.iconImage = controllerModel.icon
        }

        switch localizedViewModel.actionButtonState {
        case let .enabled(isEnabled):
            rootView.actionButton.isEnabled = isEnabled
            rootView.actionButton.isHidden = false
        case .hidden:
            rootView.actionButton.isHidden = true
        }
    }
}
