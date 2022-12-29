import SoraFoundation

protocol NetworkInfoViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func set(nameViewModel: InputViewModelProtocol)
    func set(nodeViewModel: InputViewModelProtocol)
    func set(chain: ChainModel)
}

protocol NetworkInfoPresenterProtocol: AnyObject {
    func setup()

    func activateCopy()
    func activateClose()
    func activateUpdate()
}

protocol NetworkInfoInteractorInputProtocol: AnyObject {
    func updateNode(
        _ node: ChainNodeModel,
        newURL: URL,
        newName: String
    )
}

protocol NetworkInfoInteractorOutputProtocol: AnyObject {
    func didStartConnectionUpdate(with url: URL)
    func didCompleteConnectionUpdate(with url: URL)
    func didReceive(error: Error, for url: URL)
}

protocol NetworkInfoWireframeProtocol: SheetAlertPresentable, ErrorPresentable, ModalAlertPresenting {
    func close(view: NetworkInfoViewProtocol?)
}

protocol NetworkInfoViewFactoryProtocol: AnyObject {
    static func createView(
        with chain: ChainModel,
        mode: NetworkInfoMode,
        node: ChainNodeModel
    ) -> NetworkInfoViewProtocol?
}
