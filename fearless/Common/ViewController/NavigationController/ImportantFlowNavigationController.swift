import UIKit
import SoraFoundation

class ImportantFlowNavigationController: FearlessNavigationController {
    let localizationManager: LocalizationManagerProtocol

    init(
        rootViewController: UIViewController,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.localizationManager = localizationManager

        // from iOS 13 we can do init(rootController:) but due to iOS 12 bug need to stick to this approach
        super.init(nibName: nil, bundle: nil)

        viewControllers = [rootViewController]
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

extension ImportantFlowNavigationController: UIAdaptivePresentationControllerDelegate, SheetAlertPresentable {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        let containsImportantViews = viewControllers.contains { ($0 as? ImportantViewProtocol) != nil }
        return !containsImportantViews
    }

    func presentationControllerDidAttemptToDismiss(_: UIPresentationController) {
        let languages = localizationManager.selectedLocale.rLanguages

        let action = SheetAlertPresentableAction(
            title: R.string.localizable.commonCancelOperationAction(preferredLanguages: languages),
            button: UIFactory.default.createDestructiveButton()
        ) { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.commonCancelOperationMessage(preferredLanguages: languages),
            message: nil,
            actions: [action],
            closeAction: R.string.localizable.commonKeepEditingAction(preferredLanguages: languages),
            icon: R.image.iconWarningBig()
        )

        present(viewModel: viewModel, from: self)
    }
}
