import Foundation

protocol SelectionListViewProtocol: ControllerBackedProtocol {
    func didReload()
}

protocol SelectionListPresenterProtocol: AnyObject {
    var numberOfItems: Int { get }

    func item(at index: Int) -> SelectableViewModelProtocol
    func selectItem(at index: Int)
}
