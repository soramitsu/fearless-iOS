import SoraFoundation

protocol NetworkInfoViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func set(nameViewModel: InputViewModelProtocol)
    func set(nodeViewModel: InputViewModelProtocol)
    func set(networkType: Chain)
}

protocol NetworkInfoPresenterProtocol: AnyObject {
    func setup()

    func activateCopy()
    func activateClose()
    func activateUpdate()
}

protocol NetworkInfoInteractorInputProtocol: AnyObject {
    func updateConnection(
        _ oldConnection: ConnectionItem,
        newURL: URL,
        newName: String
    )
}

protocol NetworkInfoInteractorOutputProtocol: AnyObject {
    func didStartConnectionUpdate(with url: URL)
    func didCompleteConnectionUpdate(with url: URL)
    func didReceive(error: Error, for url: URL)
}

protocol NetworkInfoWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting {
    func close(view: NetworkInfoViewProtocol?)
}

protocol NetworkInfoViewFactoryProtocol: AnyObject {
    static func createView(with connectionItem: ConnectionItem, mode: NetworkInfoMode) -> NetworkInfoViewProtocol?
}
