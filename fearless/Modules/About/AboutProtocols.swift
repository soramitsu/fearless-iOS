import CommonWallet

protocol AboutViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: [AboutViewModel])
    func didReceive(locale: Locale)
}

protocol AboutPresenterProtocol: AnyObject {
    func didLoad(view: AboutViewProtocol)

    func activateWriteUs()
    func activate(url: URL)
}

protocol AboutWireframeProtocol: WebPresentable, EmailPresentable, AlertPresentable {}

protocol AboutViewFactoryProtocol: AnyObject {
    static func createView() -> AboutViewProtocol?
}
