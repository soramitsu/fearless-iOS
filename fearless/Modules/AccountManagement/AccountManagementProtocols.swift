import Foundation
import RobinHood

protocol AccountManagementViewProtocol: ControllerBackedProtocol {
    func reload()

    func didRemoveItem(at index: Int, in section: Int)
    func didRemoveSection(at section: Int)
}

protocol AccountManagementPresenterProtocol: AnyObject {
    func setup()

    func numberOfSections() -> Int
    func section(at index: Int) -> ManagedAccountViewModelSection

    func activateDetails(at index: Int, in section: Int)
    func activateAddAccount()

    func selectItem(at index: Int, in section: Int)
    func moveItem(at startIndex: Int, to finalIndex: Int, in section: Int)

    func removeItem(at index: Int, in section: Int)
    func removeSection(at index: Int)
}

protocol AccountManagementInteractorInputProtocol: AnyObject {
    func setup()
    func select(item: ManagedAccountItem)
    func save(items: [ManagedAccountItem])
    func remove(item: ManagedAccountItem)
}

protocol AccountManagementInteractorOutputProtocol: AnyObject {
    func didReceiveSelected(item: AccountItem)
    func didReceive(changes: [DataProviderChange<ManagedAccountItem>])
    func didReceive(error: Error)
}

protocol AccountManagementWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showAccountDetails(_ account: ManagedAccountItem, from view: AccountManagementViewProtocol?)
    func showAddAccount(from view: AccountManagementViewProtocol?)
    func complete(from view: AccountManagementViewProtocol?)
}

protocol AccountManagementViewFactoryProtocol: AnyObject {
    static func createViewForSettings() -> AccountManagementViewProtocol?
    static func createViewForSwitch() -> AccountManagementViewProtocol?
}
