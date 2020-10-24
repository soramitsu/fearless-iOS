import Foundation
import SoraFoundation

protocol AddConnectionViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func set(nameViewModel: InputViewModelProtocol)
    func set(nodeViewModel: InputViewModelProtocol)
}

protocol AddConnectionPresenterProtocol: class {
    func setup()
    func add()
}

protocol AddConnectionInteractorInputProtocol: class {
    func addConnection(url: URL, name: String)
}

protocol AddConnectionInteractorOutputProtocol: class {
    func didStartAdding(url: URL)
    func didCompleteAdding(url: URL)
    func didReceiveError(error: Error, for url: URL)
}

protocol AddConnectionWireframeProtocol: AlertPresentable, ErrorPresentable {
    func close(view: AddConnectionViewProtocol?)
}

protocol AddConnectionViewFactoryProtocol: class {
	static func createView() -> AddConnectionViewProtocol?
}
