import RobinHood
import IrohaCrypto

protocol NetworkManagementViewProtocol: ControllerBackedProtocol {
    func reload()

    func didRemoveCustomItem(at index: Int)
}

protocol NetworkManagementPresenterProtocol: class {
    func activateConnectionAdd()

    func activateDefaultConnectionDetails(at index: Int)
    func activateCustomConnectionDetails(at index: Int)

    func selectDefaultItem(at index: Int)
    func selectCustomItem(at index: Int)

    func moveCustomItem(at startIndex: Int, to finalIndex: Int)

    func removeCustomItem(at index: Int)

    func numberOfDefaultConnections() -> Int
    func defaultConnection(at index: Int) -> ManagedConnectionViewModel

    func numberOfCustomConnections() -> Int
    func customConnection(at index: Int) -> ManagedConnectionViewModel

    func setup()
}

protocol NetworkManagementInteractorInputProtocol: class {
    func setup()
    func select(connection: ConnectionItem)
    func select(connection: ConnectionItem, account: AccountItem)
    func save(items: [ManagedConnectionItem])
    func remove(item: ManagedConnectionItem)
}

protocol NetworkManagementInteractorOutputProtocol: class {
    func didReceiveSelectedConnection(_ item: ConnectionItem)
    func didReceiveDefaultConnections(_ connections: [ConnectionItem])
    func didReceiveCustomConnection(changes: [DataProviderChange<ManagedConnectionItem>])
    func didReceiveCustomConnection(error: Error)

    func didFindMultiple(accounts: [AccountItem], for connection: ConnectionItem)
    func didFindNoAccounts(for connection: ConnectionItem)
    func didReceiveConnection(selectionError: Error)
}

protocol NetworkManagementWireframeProtocol: ErrorPresentable, AlertPresentable {
    func presentAccountSelection(_ accounts: [AccountItem],
                                 addressType: SNAddressType,
                                 delegate: ModalPickerViewControllerDelegate,
                                 from view: NetworkManagementViewProtocol?,
                                 context: AnyObject?)

    func presentAccountCreation(for connection: ConnectionItem,
                                from view: NetworkManagementViewProtocol?)

    func presentConnectionInfo(_ connectionItem: ConnectionItem,
                               mode: NetworkInfoMode,
                               from view: NetworkManagementViewProtocol?)

    func presentConnectionAdd(from view: NetworkManagementViewProtocol?)

    func complete(from view: NetworkManagementViewProtocol?)
}

protocol NetworkManagementViewFactoryProtocol: class {
	static func createView() -> NetworkManagementViewProtocol?
}
