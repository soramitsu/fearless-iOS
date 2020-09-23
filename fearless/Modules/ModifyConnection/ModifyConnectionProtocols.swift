import Foundation
import SoraFoundation

protocol ModifyConnectionViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func set(nameViewModel: InputViewModelProtocol)
    func set(nodeViewModel: InputViewModelProtocol)
}

protocol ModifyConnectionPresenterProtocol: class {
    func setup()
    func add()
}

protocol ModifyConnectionInteractorInputProtocol: class {
    func addConnection(url: URL, name: String)
}

protocol ModifyConnectionInteractorOutputProtocol: class {
    func didStartAdding(url: URL)
    func didCompleteAdding(url: URL)
    func didReceiveError(error: Error, for url: URL)
}

protocol ModifyConnectionWireframeProtocol: AlertPresentable, ErrorPresentable {
    func close(view: ModifyConnectionViewProtocol?)
}

protocol ModifyConnectionViewFactoryProtocol: class {
	static func createView() -> ModifyConnectionViewProtocol?
}
