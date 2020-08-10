protocol AccountConfirmViewProtocol: ControllerBackedProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool)
}

protocol AccountConfirmPresenterProtocol: class {
    func setup()
    func requestWords()
    func confirm(words: [String])
}

protocol AccountConfirmInteractorInputProtocol: class {
    func requestWords()
    func confirm(words: [String])
}

protocol AccountConfirmInteractorOutputProtocol: class {
    func didReceive(words: [String], afterConfirmationFail: Bool)
    func didCompleteConfirmation()
    func didReceive(error: Error)
}

protocol AccountConfirmWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceed()
}

protocol AccountConfirmViewFactoryProtocol: class {
	static func createView() -> AccountConfirmViewProtocol?
}
