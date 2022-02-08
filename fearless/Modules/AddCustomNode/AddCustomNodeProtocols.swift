protocol AddCustomNodeViewProtocol: ControllerBackedProtocol {
    func didReceive(state: AddCustomNodeViewState)
}

protocol AddCustomNodePresenterProtocol: AnyObject {
    func setup()
    
    func nameTextFieldValueChanged(_ value: String)
    func addressTextFieldValueChanged(_ value: String)
}

protocol AddCustomNodeInteractorInputProtocol: AnyObject {}

protocol AddCustomNodeInteractorOutputProtocol: AnyObject {}

protocol AddCustomNodeWireframeProtocol: AnyObject {}

protocol AddCustomNodeModuleOutput: AnyObject {}
