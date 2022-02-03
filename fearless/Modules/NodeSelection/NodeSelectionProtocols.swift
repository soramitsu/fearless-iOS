import Foundation

protocol NodeSelectionViewProtocol: ControllerBackedProtocol {
    func didReceive(state: NodeSelectionViewState)
    func didReceive(locale: Locale)
}

protocol NodeSelectionPresenterProtocol: AnyObject {
    func setup()
    func didSelectNode(_ node: ChainNodeModel)
}

protocol NodeSelectionInteractorInputProtocol: AnyObject {
    func setup()
    func selectNode(_ node: ChainNodeModel)
}

protocol NodeSelectionInteractorOutputProtocol: AnyObject {
    func didReceive(chain: ChainModel)
}

protocol NodeSelectionWireframeProtocol: AnyObject {}
