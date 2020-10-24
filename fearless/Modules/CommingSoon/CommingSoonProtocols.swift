protocol CommingSoonViewProtocol: ControllerBackedProtocol {}

protocol CommingSoonPresenterProtocol: class {
    func setup()
    func activateDevStatus()
    func activateRoadmap()
}

protocol CommingSoonInteractorInputProtocol: class {}

protocol CommingSoonInteractorOutputProtocol: class {}

protocol CommingSoonWireframeProtocol: WebPresentable {}

protocol CommingSoonViewFactoryProtocol: class {
	static func createView() -> CommingSoonViewProtocol?
}
