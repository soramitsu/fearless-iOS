import Foundation
import SoraFoundation

protocol AccessRestoreViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveView(model: InputViewModelProtocol)
}

protocol AccessRestorePresenterProtocol: class {
    func load()
    func activateAccessRestoration()
}

protocol AccessRestoreInteractorInputProtocol: class {
    func restoreAccess(mnemonic: String)
}

protocol AccessRestoreInteractorOutputProtocol: class {
    func didRestoreAccess(from mnemonic: String)
    func didReceiveRestoreAccess(error: Error)
}

protocol AccessRestoreWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showNext(from view: AccessRestoreViewProtocol?)
}

protocol AccessRestoreViewFactoryProtocol: class {
    static func createView() -> AccessRestoreViewProtocol?
}
