import Foundation
import RobinHood

protocol AccountManagementViewProtocol: ControllerBackedProtocol {
    func reload()
}

protocol AccountManagementPresenterProtocol: class {
    func setup()

    func numberOfSections() -> Int
    func section(at index: Int) -> ManagedAccountViewModelSection

    func activateDetails(at index: Int, in section: Int)
    func selectItem(at index: Int, in section: Int)
    func moveItem(at startIndex: Int, to finalIndex: Int, in section: Int)
    func removeItem(at index: Int, in section: Int)
}

protocol AccountManagementInteractorInputProtocol: class {
    func setup()
    func select(item: ManagedAccountItem)
    func save(items: [ManagedAccountItem])
    func remove(item: ManagedAccountItem)
}

protocol AccountManagementInteractorOutputProtocol: class {
    func didReceiveSelected(item: AccountItem)
    func didReceive(changes: [DataProviderChange<ManagedAccountItem>])
    func didReceive(error: Error)
}

protocol AccountManagementWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showAccountDetails(_ account: ManagedAccountItem, from view: AccountManagementViewProtocol?)
    func showAddAccount(from view: AccountManagementViewProtocol?)
}

protocol AccountManagementViewFactoryProtocol: class {
	static func createView() -> AccountManagementViewProtocol?
}
