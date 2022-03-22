protocol WarningAlertViewProtocol: ControllerBackedProtocol {
    func didReceive(config: WarningAlertConfig)
}

protocol WarningAlertPresenterProtocol: AnyObject {
    func didLoad(view: WarningAlertViewProtocol)
    func didTapActionButton()
    func didTapCloseButton()
}

protocol WarningAlertInteractorInputProtocol: AnyObject {}

protocol WarningAlertInteractorOutputProtocol: AnyObject {}

protocol WarningAlertWireframeProtocol: AnyObject, PresentDismissable {}
