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

    func activateWalletDetails(at index: Int)
    func activateAddAccount()

    func selectItem(at index: Int)
    func moveItem(at startIndex: Int, to finalIndex: Int)

    func removeItem(at index: Int)

    func didTapCloseButton()
}

protocol AccountManagementInteractorInputProtocol: AnyObject {
    func setup()
    func select(item: ManagedMetaAccountModel)
    func save(items: [ManagedMetaAccountModel])
    func remove(item: ManagedMetaAccountModel)
    func update(item: ManagedMetaAccountModel)
}

protocol AccountManagementInteractorOutputProtocol: EventVisitorProtocol {
    func didCompleteSelection(of metaAccount: MetaAccountModel)
    func didReceive(changes: [DataProviderChange<ManagedMetaAccountModel>])
    func didReceive(error: Error)
}

protocol AccountManagementWireframeProtocol: SheetAlertPresentable, ErrorPresentable {
    func showAccountDetails(
        from view: AccountManagementViewProtocol?,
        metaAccount: MetaAccountModel
    )
    func showAddAccount(from view: AccountManagementViewProtocol?)
    func complete(from view: AccountManagementViewProtocol?)
    func showWalletSettings(
        from view: AccountManagementViewProtocol?,
        items: [WalletSettingsRow],
        callback: @escaping ModalPickerSelectionCallback
    )
    func showSelectAccounts(
        from view: AccountManagementViewProtocol?,
        managedMetaAccountModel: ManagedMetaAccountModel
    )
}

protocol AccountManagementViewFactoryProtocol: AnyObject {
    static func createViewForSettings() -> AccountManagementViewProtocol?
    static func createViewForSwitch() -> AccountManagementViewProtocol?
}
