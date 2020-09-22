import SoraFoundation

protocol NetworkInfoViewProtocol: ControllerBackedProtocol {
    func set(nameViewModel: InputViewModelProtocol)
    func set(nodeViewModel: InputViewModelProtocol)
}

protocol NetworkInfoPresenterProtocol: class {
    func setup()

    func activateCopy()
    func activateClose()
}

protocol NetworkInfoInteractorInputProtocol: class {}

protocol NetworkInfoInteractorOutputProtocol: class {}

protocol NetworkInfoWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting {
    func close(view: NetworkInfoViewProtocol?)
}

protocol NetworkInfoViewFactoryProtocol: class {
	static func createView(with connectionItem: ConnectionItem, readOnly: Bool) -> NetworkInfoViewProtocol?
}
