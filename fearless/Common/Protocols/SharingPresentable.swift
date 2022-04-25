import UIKit

typealias SharingCompletionHandler = (Bool) -> Void

protocol SharingPresentable {
    func share(
        source: UIActivityItemSource,
        from view: ControllerBackedProtocol?,
        with completionHandler: SharingCompletionHandler?
    )

    func share(
        sources: [Any],
        from view: ControllerBackedProtocol?,
        with completionHandler: SharingCompletionHandler?
    )
}

extension SharingPresentable {
    func share(
        source: UIActivityItemSource,
        from view: ControllerBackedProtocol?,
        with completionHandler: SharingCompletionHandler?
    ) {
        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let activityController = UIActivityViewController(
            activityItems: [source],
            applicationActivities: nil
        )

        if let handler = completionHandler {
            activityController.completionWithItemsHandler = { _, completed, _, _ in
                handler(completed)
            }
        }

        controller.present(activityController, animated: true, completion: nil)
    }

    func share(
        sources: [Any],
        from view: ControllerBackedProtocol?,
        with completionHandler: SharingCompletionHandler?
    ) {
        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let activityController = UIActivityViewController(
            activityItems: sources,
            applicationActivities: nil
        )

        if let handler = completionHandler {
            activityController.completionWithItemsHandler = { _, completed, _, _ in
                handler(completed)
            }
        }

        controller.present(activityController, animated: true, completion: nil)
    }
}
