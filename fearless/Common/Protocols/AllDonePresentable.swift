import UIKit
import SoraUI

protocol AllDonePresentable {
    func presentDone(
        title: String?,
        description: String?,
        extrinsicHash: String,
        from view: ControllerBackedProtocol,
        closure: (() -> Void)?
    )
}

extension AllDonePresentable {
    func presentDone(
        title: String? = nil,
        description: String? = nil,
        extrinsicHash: String,
        from view: ControllerBackedProtocol,
        closure: (() -> Void)? = nil
    ) {
        if let controller = AllDoneAssembly.configureModule(
            title: title,
            description: description,
            with: extrinsicHash,
            closure: closure
        )?.view.controller {
            controller.modalPresentationStyle = .custom

            let factory = ModalSheetBlurPresentationFactory(
                configuration: ModalSheetPresentationConfiguration.fearlessBlur
            )
            controller.modalTransitioningFactory = factory

            let presentingViewController = view.controller.presentedViewController ?? view.controller
            presentingViewController.present(controller, animated: true)
        }
    }
}
