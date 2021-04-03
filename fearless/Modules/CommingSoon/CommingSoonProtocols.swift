protocol CommingSoonViewProtocol: ControllerBackedProtocol {}

protocol CommingSoonPresenterProtocol: AnyObject {
    func setup()
    func activateDevStatus()
    func activateRoadmap()
}

protocol CommingSoonInteractorInputProtocol: AnyObject {}

protocol CommingSoonInteractorOutputProtocol: AnyObject {}

protocol CommingSoonWireframeProtocol: WebPresentable {}

protocol CommingSoonViewFactoryProtocol: AnyObject {
    static func createView() -> CommingSoonViewProtocol?
}
