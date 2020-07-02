protocol NodeSelectionViewProtocol: SelectionListViewProtocol {}

protocol NodeSelectionPresenterProtocol: SelectionListPresenterProtocol {
    func setup()
}

protocol NodeSelectionInteractorInputProtocol: class {
    func load()
    func select(nodeItem: NodeSelectionItem)
}

protocol NodeSelectionInteractorOutputProtocol: class {
    func didLoad(selectedNodeItem: NodeSelectionItem)
    func didLoad(nodeItems: [NodeSelectionItem])
}

protocol NodeSelectionViewFactoryProtocol: class {
    static func createView() -> NodeSelectionViewProtocol?
}
