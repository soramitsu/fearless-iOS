import SoraFoundation

protocol CrowdloanListViewProtocol: ControllerBackedProtocol, Localizable {}

protocol CrowdloanListPresenterProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol CrowdloanListInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol CrowdloanListInteractorOutputProtocol: AnyObject {}

protocol CrowdloanListWireframeProtocol: AnyObject {}
