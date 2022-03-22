protocol WarningAlertViewProtocol: AnyObject, ControllerBackedProtocol {
    func didReceive(config: WarningAlertConfig)
}

protocol WarningAlertPresenterProtocol: AnyObject {
    func setup()
    func didTapActionButton()
    func didTapCloseButton()
}

protocol WarningAlertInteractorInputProtocol: AnyObject {}

protocol WarningAlertInteractorOutputProtocol: AnyObject {}

protocol WarningAlertWireframeProtocol: AnyObject, PresentDismissable {}
