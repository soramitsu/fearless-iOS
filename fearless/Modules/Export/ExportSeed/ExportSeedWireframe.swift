import UIKit

final class ExportSeedWireframe: ExportSeedWireframeProtocol {
    private weak var activityController: SeedShareActivityViewController?

    func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        guard let controller = view?.controller else { return }
        let sheet = SheetAletViewController(
            viewModel: viewModel,
            externalDismissalCompletion: viewModel.dismissCompletion
        )
        sheet.modalPresentationStyle = .custom
        sheet.modalTransitioningFactory = ModalSheetBlurPresentationFactory(
            configuration: .fearlessBlur,
            shouldDissmissWhenTapOnBlurArea: viewModel.dismissCompletion == nil
        )
        controller.present(sheet, animated: true)
    }

    func share(
        source: UIActivityItemSource,
        from view: ControllerBackedProtocol?,
        with completionHandler: SharingCompletionHandler?
    ) {
        guard let controller = view?.controller,
              controller.viewIfLoaded?.window != nil,
              !controller.isBeingDismissed,
              controller.presentedViewController == nil,
              activityController == nil else {
            completionHandler?(false)
            return
        }
        let activity = SeedShareActivityViewController(activityItems: [source], applicationActivities: nil)
        activityController = activity
        activity.onCompletion = { [weak self, weak activity] completed in
            if self?.activityController === activity {
                self?.activityController = nil
            }
            completionHandler?(completed)
        }
        activity.completionWithItemsHandler = { [weak activity] _, completed, _, _ in
            activity?.finish(completed)
        }
        if let popover = activity.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(
                x: controller.view.bounds.midX,
                y: controller.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }
        activity.presentationController?.delegate = activity
        controller.present(activity, animated: true)
    }

    func back(view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func showJsonExport(flow: ExportFlow, from view: ExportGenericViewProtocol?) {
        guard let passwordView = AccountExportPasswordViewFactory.createView(flow: flow) else {
            return
        }

        view?.controller.navigationController?.pushViewController(passwordView.controller, animated: true)
    }
}

/// Owns the terminal callback even when another controller dismisses the sheet.
private final class SeedShareActivityViewController: UIActivityViewController,
    UIAdaptivePresentationControllerDelegate {
    var onCompletion: SharingCompletionHandler?

    func finish(_ completed: Bool) {
        let callback = onCompletion
        onCompletion = nil
        callback?(completed)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            // UIKit delivers an activity's result after viewDidDisappear in
            // the same dismissal turn. Let that acknowledgement win before
            // treating an externally dismissed sheet as cancelled.
            DispatchQueue.main.async { self.finish(false) }
        }
    }

    func presentationControllerDidDismiss(_: UIPresentationController) {
        finish(false)
    }
}
