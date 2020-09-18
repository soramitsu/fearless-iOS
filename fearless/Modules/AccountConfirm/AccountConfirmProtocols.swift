protocol AccountConfirmViewProtocol: ControllerBackedProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool)
}

protocol AccountConfirmPresenterProtocol: class {
    func setup()
    func requestWords()
    func confirm(words: [String])
    func skip()
}

protocol AccountConfirmInteractorInputProtocol: class {
    func requestWords()
    func confirm(words: [String])
    func skipConfirmation()
}

protocol AccountConfirmInteractorOutputProtocol: class {
    func didReceive(words: [String], afterConfirmationFail: Bool)
    func didCompleteConfirmation()
    func didReceive(error: Error)
}

protocol AccountConfirmWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceed(from view: AccountConfirmViewProtocol?)
}

protocol AccountConfirmViewFactoryProtocol: class {
    static func createViewForOnboarding(request: AccountCreationRequest,
                                        metadata: AccountCreationMetadata) -> AccountConfirmViewProtocol?
    static func createViewForAdding(request: AccountCreationRequest,
                                    metadata: AccountCreationMetadata) -> AccountConfirmViewProtocol?
    static func createViewForConnection(item: ConnectionItem,
                                        request: AccountCreationRequest,
                                        metadata: AccountCreationMetadata) -> AccountConfirmViewProtocol?
}
