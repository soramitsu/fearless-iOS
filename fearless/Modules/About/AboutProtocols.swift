import Foundation

protocol AboutViewProtocol: ControllerBackedProtocol {
    func didReceive(state: AboutViewState)
    func didReceive(locale: Locale)
}

protocol AboutPresenterProtocol: AnyObject {
    func didLoad(view: AboutViewProtocol)

    func activateWriteUs()
    func activate(url: URL)
}

protocol AboutWireframeProtocol: WebPresentable, EmailPresentable, SheetAlertPresentable {}

protocol AboutViewFactoryProtocol: AnyObject {
    static func createView() -> AboutViewProtocol?
}
