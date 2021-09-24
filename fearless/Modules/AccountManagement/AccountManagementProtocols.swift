import Foundation
import RobinHood

protocol AccountManagementViewProtocol: ControllerBackedProtocol {
    func reload()

    func didRemoveItem(at index: Int)
}

protocol AccountManagementPresenterProtocol: AnyObject {
    func setup()

    func numberOfItems() -> Int

    func item(at index: Int) -> ManagedAccountViewModelItem

    func activateDetails(at index: Int)
    func activateAddAccount()

    func selectItem(at index: Int)
    func moveItem(at startIndex: Int, to finalIndex: Int)

    func removeItem(at index: Int)
}

protocol AccountManagementInteractorInputProtocol: AnyObject {
    func setup()
    func select(item: ManagedMetaAccountModel)
    func save(items: [ManagedMetaAccountModel])
    func remove(item: ManagedMetaAccountModel)
}

protocol AccountManagementInteractorOutputProtocol: AnyObject {
    func didCompleteSelection(of metaAccount: MetaAccountModel)
    func didReceive(changes: [DataProviderChange<ManagedMetaAccountModel>])
    func didReceive(error: Error)
}

protocol AccountManagementWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showAccountDetails(from view: AccountManagementViewProtocol?, metaAccount: MetaAccountModel)
    func showAddAccount(from view: AccountManagementViewProtocol?)
    func complete(from view: AccountManagementViewProtocol?)
}

protocol AccountManagementViewFactoryProtocol: AnyObject {
    static func createViewForSettings() -> AccountManagementViewProtocol?
    static func createViewForSwitch() -> AccountManagementViewProtocol?
}
