protocol AccountConfirmViewProtocol: ControllerBackedProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool)
}

protocol AccountConfirmPresenterProtocol: AnyObject {
    func didLoad(view: AccountConfirmViewProtocol)
    func requestWords()
    func confirm(words: [String])
    func skip()
}

protocol AccountConfirmInteractorInputProtocol: AnyObject {
    var flow: AccountConfirmFlow? { get }

    func requestWords()
    func confirm(words: [String])
    func skipConfirmation()
}

protocol AccountConfirmInteractorOutputProtocol: AnyObject {
    func didReceive(words: [String], afterConfirmationFail: Bool)
    func didCompleteConfirmation()
    func didReceive(error: Error)
}

protocol AccountConfirmWireframeProtocol: SheetAlertPresentable, ErrorPresentable {
    func proceed(from view: AccountConfirmViewProtocol?, flow: AccountConfirmFlow?)
}

protocol AccountConfirmViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(
        flow: AccountConfirmFlow
    ) -> AccountConfirmViewProtocol?
    static func createViewForAdding(
        flow: AccountConfirmFlow
    ) -> AccountConfirmViewProtocol?
    static func createViewForSwitch(
        flow: AccountConfirmFlow
    ) -> AccountConfirmViewProtocol?
}
