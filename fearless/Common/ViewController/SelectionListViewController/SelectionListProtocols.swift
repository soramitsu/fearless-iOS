import Foundation

protocol SelectionListViewProtocol: ControllerBackedProtocol {
    func didReload()
    func bind(viewModel: TextSearchViewModel?)
    func reloadCell(at indexPath: IndexPath)
    func didReceive(errorMessage: String?)
}

extension SelectionListViewProtocol {
    func reloadCell(at _: IndexPath) {}
}

protocol SelectionListPresenterProtocol: AnyObject, SelectionItemViewDelegate {
    var numberOfItems: Int { get }

    func item(at index: Int) -> SelectableViewModelProtocol
    func selectItem(at index: Int)

    func searchItem(with text: String?)
    func didTapRetry()
}

extension SelectionListPresenterProtocol {
    func searchItem(with _: String?) {}
    func didTapRetry() {}
}
