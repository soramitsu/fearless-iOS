import SoraFoundation

protocol ControllerAccountConfirmationViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: LocalizableResource<ControllerAccountConfirmationVM>)
}

protocol ControllerAccountConfirmationPresenterProtocol: AnyObject {
    func setup()
}

protocol ControllerAccountConfirmationInteractorInputProtocol: AnyObject {}

protocol ControllerAccountConfirmationInteractorOutputProtocol: AnyObject {}

protocol ControllerAccountConfirmationWireframeProtocol: AnyObject {}
