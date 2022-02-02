import Foundation

protocol NodeSelectionViewProtocol: ControllerBackedProtocol {
    func didReceive(state: NodeSelectionViewState)
    func didReceive(locale: Locale)
}

protocol NodeSelectionPresenterProtocol: AnyObject {
    func setup()
}

protocol NodeSelectionInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NodeSelectionInteractorOutputProtocol: AnyObject {
    func didReceive(chain: ChainModel)
}

protocol NodeSelectionWireframeProtocol: AnyObject {}
