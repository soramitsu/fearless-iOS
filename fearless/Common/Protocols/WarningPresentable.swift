import Foundation

protocol WarningPresentable {
    func presentWarningAlert(
        from view: ControllerBackedProtocol?,
        config: WarningAlertConfig,
        buttonHandler: @escaping WarningAlertButtonHandler
    )
}

extension WarningPresentable {
    func presentWarningAlert(
        from view: ControllerBackedProtocol?,
        config: WarningAlertConfig,
        buttonHandler: @escaping WarningAlertButtonHandler
    ) {
        let alertView = WarningAlertViewFactory.createView(alertConfig: config, buttonHandler: buttonHandler)
        guard let controller = alertView?.controller else {
            return
        }

        view?.controller.present(controller, animated: true, completion: nil)
    }
}
