import Foundation

protocol SelectionListViewProtocol: ControllerBackedProtocol {
    func didReload()
    func bind(viewModel: TextSearchViewModel?)
    func reloadCell(at indexPath: IndexPath)
}

extension SelectionListViewProtocol {
    func reloadCell(at _: IndexPath) {}
}

protocol SelectionListPresenterProtocol: AnyObject, SelectionItemViewDelegate {
    var numberOfItems: Int { get }

    func item(at index: Int) -> SelectableViewModelProtocol
    func selectItem(at index: Int)

    func searchItem(with text: String?)
}

extension SelectionListPresenterProtocol {
    func searchItem(with _: String?) {}
}
