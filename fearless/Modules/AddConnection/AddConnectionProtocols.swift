import Foundation
import SoraFoundation

protocol AddConnectionViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func set(nameViewModel: InputViewModelProtocol)
    func set(nodeViewModel: InputViewModelProtocol)
}

protocol AddConnectionPresenterProtocol: AnyObject {
    func setup()
    func add()
}

protocol AddConnectionInteractorInputProtocol: AnyObject {
    func addConnection(url: URL, name: String)
}

protocol AddConnectionInteractorOutputProtocol: AnyObject {
    func didStartAdding(url: URL)
    func didCompleteAdding(url: URL)
    func didReceiveError(error: Error, for url: URL)
}

protocol AddConnectionWireframeProtocol: AlertPresentable, ErrorPresentable {
    func close(view: AddConnectionViewProtocol?)
}

protocol AddConnectionViewFactoryProtocol: AnyObject {
    static func createView() -> AddConnectionViewProtocol?
}
