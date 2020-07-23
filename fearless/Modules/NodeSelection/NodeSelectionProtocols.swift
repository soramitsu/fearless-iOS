protocol NodeSelectionViewProtocol: SelectionListViewProtocol {}

protocol NodeSelectionPresenterProtocol: SelectionListPresenterProtocol {
    func setup()
}

protocol NodeSelectionInteractorInputProtocol: class {
    func load()
    func select(nodeItem: ConnectionItem)
}

protocol NodeSelectionInteractorOutputProtocol: class {
    func didLoad(selectedNodeItem: ConnectionItem)
    func didLoad(nodeItems: [ConnectionItem])
}

protocol NodeSelectionViewFactoryProtocol: class {
    static func createView() -> NodeSelectionViewProtocol?
}
