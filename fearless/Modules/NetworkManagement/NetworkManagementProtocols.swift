import RobinHood

protocol NetworkManagementViewProtocol: ControllerBackedProtocol {
    func reload()
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
}

protocol NetworkManagementInteractorOutputProtocol: class {
    func didReceiveSelectedConnection(_ item: ConnectionItem)
    func didReceiveDefaultConnections(_ connections: [ConnectionItem])
    func didReceiveCustomConnection(changes: [DataProviderChange<ManagedConnectionItem>])
    func didReceiveCustomConnection(error: Error)
}

protocol NetworkManagementWireframeProtocol: ErrorPresentable, AlertPresentable {}

protocol NetworkManagementViewFactoryProtocol: class {
	static func createView() -> NetworkManagementViewProtocol?
}
