protocol AboutViewProtocol: ControllerBackedProtocol {
    func didReceive(version: String)
}

protocol AboutPresenterProtocol: class {
    func setup()

    func activateOpensource()
    func activateTerms()
    func activatePrivacyPolicy()
    func activateWriteUs()
}

protocol AboutWireframeProtocol: WebPresentable, EmailPresentable, AlertPresentable {}

protocol AboutViewFactoryProtocol: class {
	static func createView() -> AboutViewProtocol?
}
