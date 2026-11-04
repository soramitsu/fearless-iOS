import UIKit
import SoraFoundation

final class StartupRecoveryViewController: UIViewController, ControllerBackedProtocol {
    private(set) var model: StartupRecoveryViewModel
    private let handler: (StartupRecoveryViewModel.Action) -> Void

    init(model: StartupRecoveryViewModel, handler: @escaping (StartupRecoveryViewModel.Action) -> Void) {
        self.model = model
        self.handler = handler
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
        localizationManager = LocalizationManager.shared
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        if FWAppearance.startupRecoveryRestyled {
            model = model.localized(for: localizationManager?.selectedLocalization ?? model.locale)
        }
        let layout = StartupRecoveryViewLayout()
        layout.bind(model: model) { [weak self] action in self?.perform(action) }
        view = layout
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyAdaptiveContentColumnOutsideNavigation()
    }

    private func perform(_ action: StartupRecoveryViewModel.Action) {
        switch action {
        case .emergencyExport:
            RetainedDataRestoreRouter.shared.showEmergencyMaterial(from: self)
        case .previousData:
            RetainedDataRestoreRouter.shared.showPreviousData(from: self)
        case .help:
            if let url = model.helpURL {
                UIApplication.shared.open(url)
            }
        case .restoreWalletAccess:
            RetainedDataRestoreRouter.shared.authorizeRecovery(from: self) { [weak self] granted in
                guard granted, let self else { return }
                let alert = UIAlertController(
                    title: action.localizedTitle(locale: model.locale),
                    message: RecoveryText.string("restore_access_warning", locale: model.locale),
                    preferredStyle: .alert
                )
                alert
                    .addAction(UIAlertAction(title: RecoveryText.string("close", locale: model.locale), style: .cancel))
                alert
                    .addAction(UIAlertAction(
                        title: RecoveryText.string("continue", locale: model.locale),
                        style: .default
                    ) { [weak self] _ in
                        self?.finish(action)
                    })
                self.present(alert, animated: true)
            }
        case .retry, .freshNetworkData, .continueInEnglish:
            finish(action)
        }
    }

    private func finish(_ action: StartupRecoveryViewModel.Action) {
        dismiss(animated: true) { [handler] in handler(action) }
    }
}

extension RootWireframeProtocol {
    func showStartupRecovery(
        from view: ControllerBackedProtocol?,
        model: StartupRecoveryViewModel,
        handler: @escaping (StartupRecoveryViewModel.Action) -> Void
    ) {
        view?.controller.present(StartupRecoveryViewController(model: model, handler: handler), animated: true)
    }
}

extension StartupRecoveryViewController: Localizable {
    func applyLocalization() {
        guard FWAppearance.startupRecoveryRestyled, isViewLoaded,
              let layout = view as? StartupRecoveryViewLayout else { return }
        model = model
            .localized(
                for: localizationManager?.selectedLocalization ?? LocalizationManager.shared
                    .selectedLocalization
            )
        layout.bind(model: model) { [weak self] action in self?.perform(action) }
    }
}
