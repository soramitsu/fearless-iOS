import Foundation

protocol SelectionListViewProtocol: ControllerBackedProtocol {
    func didReload()
    func bind(viewModel: TextSearchViewModel?)
}

protocol SelectionListPresenterProtocol: AnyObject {
    var numberOfItems: Int { get }

    func item(at index: Int) -> SelectableViewModelProtocol
    func selectItem(at index: Int)

    func searchItem(with text: String?)
}

extension SelectionListPresenterProtocol {
    func searchItem(with _: String?) {}
}
