import Foundation

protocol AboutViewProtocol: ControllerBackedProtocol {
    func didReceive(state: AboutViewState)
    func didReceive(locale: Locale)
}

protocol AboutPresenterProtocol: AnyObject {
    func didLoad(view: AboutViewProtocol)

    func activateFontLicenses()
    func activateWriteUs()
    func activate(url: URL)
}

protocol AboutWireframeProtocol: WebPresentable, EmailPresentable, SheetAlertPresentable {
    func showFontLicenses(from view: AboutViewProtocol, locale: Locale)
}

protocol AboutViewFactoryProtocol: AnyObject {
    static func createView() -> AboutViewProtocol?
}
