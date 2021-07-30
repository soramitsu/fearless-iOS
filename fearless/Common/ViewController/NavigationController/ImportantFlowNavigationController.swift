import UIKit
import SoraFoundation

class ImportantFlowNavigationController: FearlessNavigationController, ControllerBackedProtocol {
    let localizationManager: LocalizationManagerProtocol

    init(
        rootViewController: UIViewController,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.localizationManager = localizationManager

        super.init(rootViewController: rootViewController)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presentationController?.delegate = self
    }
}

extension ImportantFlowNavigationController: UIAdaptivePresentationControllerDelegate, AlertPresentable {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        let containsImportantViews = viewControllers.contains { ($0 as? ImportantViewProtocol) != nil }
        return !containsImportantViews
    }

    func presentationControllerDidAttemptToDismiss(_: UIPresentationController) {
        let languages = localizationManager.selectedLocale.rLanguages

        let action = AlertPresentableAction(
            title: R.string.localizable.commonCancelOperationAction(preferredLanguages: languages),
            style: .destructive
        ) { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.commonCancelOperationMessage(preferredLanguages: languages),
            message: nil,
            actions: [action],
            closeAction: R.string.localizable.commonKeepEditingAction(preferredLanguages: languages)
        )

        present(viewModel: viewModel, style: .actionSheet, from: self)
    }
}
