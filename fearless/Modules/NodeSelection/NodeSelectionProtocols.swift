protocol NodeSelectionViewProtocol: SelectionListViewProtocol {}

protocol NodeSelectionPresenterProtocol: SelectionListPresenterProtocol {
    func setup()
}

protocol NodeSelectionInteractorInputProtocol: class {
    func load()
    func select(nodeItem: NodeSelectionItem)
}

protocol NodeSelectionInteractorOutputProtocol: class {
    func didLoad(nodeItem: NodeSelectionItem)
    func didLoad(nodeItems: [NodeSelectionItem])
}

protocol NodeSelectionWireframeProtocol: class {}

protocol NodeSelectionViewFactoryProtocol: class {
    static func createView() -> NodeSelectionViewProtocol?
}
