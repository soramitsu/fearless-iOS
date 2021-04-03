protocol AboutViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: AboutViewModel)
}

protocol AboutPresenterProtocol: AnyObject {
    func setup()

    func activateWebsite()
    func activateOpensource()
    func activateSocial()
    func activateWriteUs()
    func activateTerms()
    func activatePrivacyPolicy()
}

protocol AboutWireframeProtocol: WebPresentable, EmailPresentable, AlertPresentable {}

protocol AboutViewFactoryProtocol: AnyObject {
    static func createView() -> AboutViewProtocol?
}
