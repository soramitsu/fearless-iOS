import SoraFoundation

protocol AddCustomNodeViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(nameViewModel: InputViewModelProtocol)
    func didReceive(nodeViewModel: InputViewModelProtocol)
}

protocol AddCustomNodePresenterProtocol: AnyObject {
    func didLoad(view: AddCustomNodeViewProtocol)
    func didTapAddNodeButton()
    func didTapCloseButton()
}

protocol AddCustomNodeInteractorInputProtocol: AnyObject {
    func addConnection(url: URL, name: String)
}

protocol AddCustomNodeInteractorOutputProtocol: AnyObject {
    func didStartAdding(url: URL)
    func didCompleteAdding(url: URL)
    func didReceiveError(error: Error, for url: URL)
}

protocol AddCustomNodeWireframeProtocol: PresentDismissable, SheetAlertPresentable, ErrorPresentable {}

protocol AddCustomNodeModuleOutput: AnyObject {
    func didChangedNodesList()
}
